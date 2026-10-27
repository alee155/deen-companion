import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../motion/motion.dart';
import '../../../theme/app_colors.dart';
import '../../domain/connectivity_state.dart';
import '../providers/connectivity_banner_provider.dart';
import '../providers/connectivity_providers.dart';

/// Wraps the whole app and shows connection status in a strip at the top.
///
/// The strip grows out of the status-bar area (the way WhatsApp's "no
/// connection" bar does) and pushes the app down, instead of floating over
/// it. Nothing is ever covered: not a title, not the notch or Dynamic Island
/// on iPhone, not Android's status bar. While it is visible the app below is
/// told the status bar is already taken care of, so its own safe-area padding
/// doesn't double up, and that padding is animated along with the strip so
/// content glides rather than jumps.
///
/// Tapping the strip while offline checks the connection again.
class ConnectivityBanner extends ConsumerWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  /// The strip's own height, below the status bar.
  static const bodyHeight = 30.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = ref.watch(connectivityBannerProvider);
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final duration = context.motion.duration(AppMotion.normal);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: banner.isVisible ? 1 : 0),
      duration: duration,
      curve: AppMotion.emphasized,
      // The app is passed as `child`, so it isn't rebuilt on every frame of
      // the slide; only the MediaQuery above it changes.
      child: child,
      builder: (context, t, app) {
        final stripHeight = (safeTop + bodyHeight) * t;
        final appMedia = media.copyWith(
          padding: media.padding.copyWith(top: safeTop * (1 - t)),
          viewPadding: media.viewPadding.copyWith(
            top: math.max(0, media.viewPadding.top * (1 - t)),
          ),
        );
        // A Stack with the strip last, not a Column with it first. The
        // visual result is the same, but a sibling placed *before* the app's
        // Navigator loses its semantics node (screen readers would never see
        // it), while one placed after it keeps it.
        return Stack(
          children: [
            Positioned.fill(
              top: stripHeight,
              child: MediaQuery(data: appMedia, child: app!),
            ),
            if (stripHeight > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: stripHeight,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.bottomCenter,
                    minHeight: 0,
                    maxHeight: safeTop + bodyHeight,
                    child: _Strip(
                      banner: banner,
                      safeTop: safeTop,
                      onTap: () =>
                          ref.read(connectivityProvider.notifier).recheck(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  final ConnectivityBannerState banner;
  final double safeTop;
  final VoidCallback onTap;

  const _Strip({
    required this.banner,
    required this.safeTop,
    required this.onTap,
  });

  bool get _restored => banner.kind == BannerKind.restored;

  String get _message {
    if (_restored) return 'Back online';
    if (banner.isChecking) return 'Checking connection…';
    return switch (banner.reason) {
      OfflineReason.unreachable => 'Can’t reach the internet · saved content',
      _ => 'You’re offline · showing saved content',
    };
  }

  @override
  Widget build(BuildContext context) {
    final background = _restored ? AppColors.success : AppColors.heroSurface;
    final foreground = _restored ? Colors.white : AppColors.onHeroSurface;
    final darkBackground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    final content = Semantics(
      // Read before the screen below it.
      sortKey: const OrdinalSortKey(-1),
      liveRegion: true,
      container: true,
      button: !_restored,
      label: _message,
      onTap: _restored ? null : onTap,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(top: safeTop),
          child: SizedBox(
            height: ConnectivityBanner.bodyHeight,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (banner.isChecking && !_restored)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: foreground,
                      ),
                    )
                  else
                    Icon(
                      _restored
                          ? Icons.check_circle_rounded
                          : Icons.wifi_off_rounded,
                      size: 15,
                      color: foreground,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: MediaQuery(
                      // A tall system font must not push the strip taller
                      // than the space reserved for it.
                      data: MediaQuery.of(context).copyWith(
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: 1.15),
                      ),
                      child: Text(
                        _message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status-bar icons must read against the strip, not the app below it.
      value: darkBackground
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Material(
        color: background,
        child: InkWell(
          onTap: _restored ? null : onTap,
          child: SizedBox(width: double.infinity, child: content),
        ),
      ),
    );
  }
}
