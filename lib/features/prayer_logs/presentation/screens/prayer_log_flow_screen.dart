import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../snaps/presentation/widgets/capture_view.dart';
import '../../../snaps/presentation/widgets/crop_view.dart';
import '../prayer_labels.dart';
import '../providers/prayer_log_composer.dart';
import '../providers/prayer_logs_providers.dart';
import '../widgets/prayer_log_confirm_view.dart';

/// "Log prayer": capture → crop → confirm. Top-level route (no bottom bar).
/// Pops with `true` once the prayer is logged; the caller shows the toast.
class PrayerLogFlowScreen extends ConsumerStatefulWidget {
  const PrayerLogFlowScreen({super.key});

  @override
  ConsumerState<PrayerLogFlowScreen> createState() =>
      _PrayerLogFlowScreenState();
}

class _PrayerLogFlowScreenState extends ConsumerState<PrayerLogFlowScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  PrayerLogComposerController get _composer =>
      ref.read(prayerLogComposerProvider.notifier);

  /// Back walks one step; from the camera it leaves the flow. Ignored while
  /// working, so a gesture can't drop an upload midway.
  void _back() {
    final s = ref.read(prayerLogComposerProvider);
    if (s.isSubmitting || s.isProcessing) return;
    switch (s.step) {
      case PrayerLogStep.capture:
        context.pop();
      case PrayerLogStep.crop || PrayerLogStep.confirm:
        _composer.retake();
    }
  }

  Future<void> _submit() async {
    final ok = await _composer.submit();
    if (ok && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(prayerLogComposerProvider);
    final open = ref.watch(currentPrayerProvider).valueOrNull?.current;
    final label = open?.prayer.label;

    final Widget body = switch (s.step) {
      PrayerLogStep.capture => CaptureView(
        key: const ValueKey('capture'),
        title: label == null ? 'Log prayer' : 'Log $label',
        titleIcon: Icons.mosque_rounded,
        isProcessing: s.isProcessing,
        onCaptured: _composer.onCaptured,
        onClose: _back,
      ),
      PrayerLogStep.crop => CropView(
        key: const ValueKey('crop'),
        image: s.source!,
        onBack: _composer.retake,
        onCropped: _composer.onCropped,
      ),
      PrayerLogStep.confirm => PrayerLogConfirmView(
        key: const ValueKey('confirm'),
        image: s.cropped!,
        prayerLabel: label,
        isProcessing: s.isProcessing,
        isSubmitting: s.isSubmitting,
        errorMessage: s.errorMessage,
        onRetake: _composer.retake,
        onRecrop: _composer.recrop,
        onSubmit: _submit,
      ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: body,
          ),
        ),
      ),
    );
  }
}
