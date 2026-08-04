import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/error/failures.dart';
import '../../core/location/location_service.dart';
import '../../core/location/location_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Riverpod hands errors over as `Object`, but everything the repositories
/// throw is a [Failure] — this keeps the cast in one place.
Failure failureFrom(Object? error) =>
    error is Failure ? error : const UnexpectedFailure();

/// One place that turns a [Failure] into a message plus the action that
/// actually resolves it.
///
/// Before this existed, every feature rendered `failure.toString()` with a
/// generic "Try again" button — so a device with Location Services switched
/// off was told it was offline, and tapping Try again did nothing but fail
/// again. A location problem now offers the system settings deep link (and
/// retries by itself once the user comes back), a permission problem offers
/// the OS prompt, and only genuine network/server problems offer a plain
/// retry.
class FailureView extends ConsumerStatefulWidget {
  final Failure failure;
  final Future<void> Function() onRetry;

  /// Tighter padding/typography for inline use inside a card.
  final bool compact;

  const FailureView({
    super.key,
    required this.failure,
    required this.onRetry,
    this.compact = false,
  });

  @override
  ConsumerState<FailureView> createState() => _FailureViewState();
}

class _FailureViewState extends ConsumerState<FailureView>
    with WidgetsBindingObserver {
  bool _awaitingSettingsReturn = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user was sent to system settings to fix location; the moment they
    // come back, re-check instead of making them hunt for a Retry button.
    if (state == AppLifecycleState.resumed && _awaitingSettingsReturn) {
      _awaitingSettingsReturn = false;
      _retry();
    }
  }

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    ref.invalidate(locationAvailabilityProvider);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  LocationErrorKind? get _locationKind {
    final failure = widget.failure;
    return failure is LocationFailure ? failure.kind : null;
  }

  IconData get _icon {
    if (_locationKind != null) return Icons.location_off_outlined;
    return switch (widget.failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      ServerFailure() => Icons.cloud_off_rounded,
      _ => Icons.error_outline_rounded,
    };
  }

  String get _title {
    return switch (_locationKind) {
      LocationErrorKind.serviceDisabled => 'Location Services are off',
      LocationErrorKind.permissionDenied => 'Location access needed',
      LocationErrorKind.permissionDeniedForever => 'Location access blocked',
      LocationErrorKind.timeout => "Couldn't find your location",
      LocationErrorKind.unavailable => 'Location unavailable',
      null => switch (widget.failure) {
        NetworkFailure() => "You're offline",
        ServerFailure() => 'Service unavailable',
        _ => 'Something went wrong',
      },
    };
  }

  Future<void> _handlePrimaryAction() async {
    final kind = _locationKind;
    final locationService = ref.read(locationServiceProvider);

    switch (kind) {
      case LocationErrorKind.serviceDisabled:
        _awaitingSettingsReturn = true;
        await locationService.openLocationSettings();
      case LocationErrorKind.permissionDeniedForever:
        _awaitingSettingsReturn = true;
        await locationService.openAppSettings();
      case LocationErrorKind.permissionDenied:
        final availability = await locationService.requestPermission();
        ref.invalidate(locationAvailabilityProvider);
        if (availability.isUsable) {
          await _retry();
        } else if (availability.permanentlyDenied) {
          _awaitingSettingsReturn = true;
          await locationService.openAppSettings();
        }
      case LocationErrorKind.timeout:
      case LocationErrorKind.unavailable:
      case null:
        await _retry();
    }
  }

  String get _primaryActionLabel => _locationKind?.actionLabel ?? 'Try again';

  bool get _showSecondaryRetry {
    final kind = _locationKind;
    return kind != null &&
        kind != LocationErrorKind.timeout &&
        kind != LocationErrorKind.unavailable;
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.compact ? 16.w : 24.w;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.worshipAccentBg,
            ),
            child: Icon(_icon, color: AppColors.worshipAccent, size: 22.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: AppTypography.headline.copyWith(
              fontSize: widget.compact ? 15.sp : 17.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            widget.failure.message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 14.h),
          if (_isRetrying)
            SizedBox(
              height: 36.h,
              child: Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.emeraldInk,
                  ),
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: _handlePrimaryAction,
              child: Text(_primaryActionLabel),
            ),
          if (_showSecondaryRetry && !_isRetrying)
            TextButton(
              onPressed: _retry,
              child: Text(
                'Try again',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
