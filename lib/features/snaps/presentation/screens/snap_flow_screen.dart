import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../providers/snap_providers.dart';
import '../widgets/capture_view.dart';
import '../widgets/crop_view.dart';
import '../widgets/edit_view.dart';
import '../widgets/recipients_view.dart';

/// "Send snap": capture → crop → preview/timer → recipients. A successful
/// send closes the flow (the caller shows the confirmation).
/// Top-level route (no bottom bar). Steps are state-driven so the back button
/// walks backwards through the flow instead of dropping the whole snap.
class SnapFlowScreen extends ConsumerStatefulWidget {
  final String groupId;
  const SnapFlowScreen({super.key, required this.groupId});

  @override
  ConsumerState<SnapFlowScreen> createState() => _SnapFlowScreenState();
}

class _SnapFlowScreenState extends ConsumerState<SnapFlowScreen> {
  @override
  void initState() {
    super.initState();
    // Snaps are portrait-only.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  SnapComposerController get _composer =>
      ref.read(snapComposerProvider(widget.groupId).notifier);

  /// Back walks one step; from the camera it leaves the flow.
  void _back() {
    final s = ref.read(snapComposerProvider(widget.groupId));
    if (s.isSending || s.isProcessing) return;
    switch (s.step) {
      case SnapStep.capture:
        context.pop();
      case SnapStep.crop || SnapStep.edit:
        _composer.retake();
      case SnapStep.recipients:
        _composer.backToEdit();
    }
  }

  Future<void> _send(List<String> recipientIds) async {
    final ok = await _composer.send(recipientIds);
    if (ok && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(snapComposerProvider(widget.groupId));
    final detail = ref.watch(groupDetailProvider(widget.groupId)).valueOrNull;
    final groupName = detail?.name ?? 'Group';

    final Widget body = switch (s.step) {
      SnapStep.capture => CaptureView(
        key: const ValueKey('capture'),
        groupId: widget.groupId,
        groupName: groupName,
        onClose: _back,
      ),
      SnapStep.crop => CropView(
        key: const ValueKey('crop'),
        image: s.source!,
        onBack: _composer.retake,
        onCropped: _composer.onCropped,
      ),
      SnapStep.edit => EditView(
        key: const ValueKey('edit'),
        image: s.cropped!,
        viewSeconds: s.viewSeconds,
        caption: s.caption,
        isProcessing: s.isProcessing,
        errorMessage: s.errorMessage,
        onRetake: _composer.retake,
        onRecrop: _composer.recrop,
        onTimerChanged: _composer.setTimer,
        onCaptionChanged: _composer.setCaption,
        onNext: _composer.continueToRecipients,
      ),
      SnapStep.recipients => RecipientsView(
        key: const ValueKey('recipients'),
        groupId: widget.groupId,
        onBack: _composer.backToEdit,
        onSend: _send,
      ),
    };

    // The back gesture is intercepted so it can't drop a snap mid-flow (or
    // mid-upload): see [_back].
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: s.step == SnapStep.recipients
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
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
