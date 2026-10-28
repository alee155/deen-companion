import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../providers/snap_providers.dart';
import '../widgets/capture_view.dart';
import '../widgets/crop_view.dart';
import '../widgets/edit_view.dart';
import '../widgets/group_picker_view.dart';

/// "Send snap": capture → crop → preview/timer → choose groups. A successful
/// send closes the flow with the number of groups it went to (the caller shows
/// the confirmation).
/// Top-level route (no bottom bar). Steps are state-driven so the back button
/// walks backwards through the flow instead of dropping the whole snap.
///
/// Opened from a group, that group is already ticked ([initialGroupId]);
/// opened from the groups list, the user ticks the groups themselves.
class SnapFlowScreen extends ConsumerStatefulWidget {
  final String? initialGroupId;
  const SnapFlowScreen({super.key, this.initialGroupId});

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
      ref.read(snapComposerProvider(widget.initialGroupId).notifier);

  /// Back walks one step; from the camera it leaves the flow.
  void _back() {
    final s = ref.read(snapComposerProvider(widget.initialGroupId));
    if (s.isSending || s.isProcessing) return;
    switch (s.step) {
      case SnapStep.capture:
        context.pop();
      case SnapStep.crop || SnapStep.edit:
        _composer.retake();
      case SnapStep.groups:
        _composer.backToEdit();
    }
  }

  Future<void> _send(List<String> groupIds) async {
    final ok = await _composer.send(groupIds);
    if (ok && mounted) context.pop(groupIds.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(snapComposerProvider(widget.initialGroupId));
    final initial = widget.initialGroupId;
    // The camera is titled with the group it was opened from, or plainly when
    // the user is yet to choose.
    final title = initial == null
        ? 'New snap'
        : ref.watch(groupDetailProvider(initial)).valueOrNull?.name ?? 'Group';

    final Widget body = switch (s.step) {
      SnapStep.capture => CaptureView(
        key: const ValueKey('capture'),
        title: title,
        isProcessing: s.isProcessing,
        onCaptured: _composer.onCaptured,
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
        onNext: _composer.continueToGroups,
      ),
      SnapStep.groups => GroupPickerView(
        key: const ValueKey('groups'),
        initialGroupId: widget.initialGroupId,
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
          value: s.step == SnapStep.groups
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
