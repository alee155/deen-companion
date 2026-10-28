import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/entities/report_target.dart';
import '../providers/moderation_providers.dart';
import '../report_labels.dart';

/// How the report sheet ended.
enum ReportOutcome {
  /// Dismissed without sending.
  cancelled,

  /// Sent.
  sent,

  /// Sent, and the user asked to block the person too.
  sentAndBlock,
}

/// Opens the report sheet for [target].
Future<ReportOutcome?> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  bool alreadyBlocked = false,
}) {
  HapticFeedback.selectionClick();
  return showGroupSheet<ReportOutcome>(
    context,
    (_) => ReportSheet(target: target, alreadyBlocked: alreadyBlocked),
  );
}

class ReportSheet extends ConsumerStatefulWidget {
  final ReportTarget target;

  /// Whether the person is already blocked (so the thank-you doesn't offer it).
  final bool alreadyBlocked;

  const ReportSheet({
    super.key,
    required this.target,
    this.alreadyBlocked = false,
  });

  /// The longest note accepted.
  static const maxDetails = 300;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _sent = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(reportControllerProvider.notifier)
        .submit(target: widget.target, reason: reason, details: _details.text);
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    return GroupSheetFrame(
      icon: _sent ? Icons.check_circle_outline_rounded : Icons.flag_outlined,
      title: _sent ? 'Report sent' : target.sheetTitle,
      subtitle: _sent ? 'Thanks for letting us know.' : target.sheetSubtitle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _sent
            ? _Sent(
                key: const ValueKey('sent'),
                name: target.userName,
                offerBlock: !widget.alreadyBlocked,
                onBlock: () =>
                    Navigator.of(context).pop(ReportOutcome.sentAndBlock),
                onDone: () => Navigator.of(context).pop(ReportOutcome.sent),
              )
            : _Form(
                key: const ValueKey('form'),
                target: target,
                reason: _reason,
                details: _details,
                onReason: (r) => setState(() => _reason = r),
                onSubmit: _submit,
              ),
      ),
    );
  }
}

class _Form extends ConsumerWidget {
  final ReportTarget target;
  final ReportReason? reason;
  final TextEditingController details;
  final ValueChanged<ReportReason> onReason;
  final VoidCallback onSubmit;

  const _Form({
    super.key,
    required this.target,
    required this.reason,
    required this.details,
    required this.onReason,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportControllerProvider);
    final busy = state.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in ReportReason.values) ...[
          _ReasonTile(
            reason: r,
            selected: reason == r,
            enabled: !busy,
            onTap: () => onReason(r),
          ),
          SizedBox(height: 7.h),
        ],
        SizedBox(height: 4.h),
        TextField(
          controller: details,
          enabled: !busy,
          maxLength: ReportSheet.maxDetails,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 14.sp, color: AppColors.inkText),
          decoration: InputDecoration(
            hintText: 'Add a note (optional)',
            hintStyle: TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: AppColors.borderWarm),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: AppColors.borderWarm),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: AppColors.emeraldInk, width: 1.6),
            ),
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 13.sp,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 5.w),
            Expanded(
              child: Text(
                'Our team reviews every report. ${target.userName} isn’t told '
                'who reported them.',
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        _KeepInView(
          watch: state.errorMessage,
          child: SheetNotice(message: state.errorMessage),
        ),
        Row(
          children: [
            Expanded(
              child: SheetSecondaryButton(
                label: 'Cancel',
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).pop(ReportOutcome.cancelled),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: SheetButton(
                label: 'Submit report',
                icon: Icons.send_rounded,
                loading: busy,
                onPressed: reason == null ? null : onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Scrolls [child] into view when [watch] changes to something, so an error
/// that appears below the fold isn't missed.
class _KeepInView extends StatefulWidget {
  final String? watch;
  final Widget child;
  const _KeepInView({required this.watch, required this.child});

  @override
  State<_KeepInView> createState() => _KeepInViewState();
}

class _KeepInViewState extends State<_KeepInView> {
  @override
  void didUpdateWidget(_KeepInView old) {
    super.didUpdateWidget(old);
    if (widget.watch != null && widget.watch != old.watch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 220),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReasonTile extends StatelessWidget {
  final ReportReason reason;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '${reason.title}. ${reason.hint}',
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? AppColors.emeraldInk.withValues(alpha: 0.10)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16.r),
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: selected ? AppColors.emeraldInk : AppColors.borderWarm,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 21.sp,
                    color: selected
                        ? AppColors.emeraldInk
                        : AppColors.textMuted,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                        // What it covers, shown for the chosen reason only: the
                        // list stays short enough to fit a small phone.
                        AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          alignment: Alignment.topLeft,
                          child: selected
                              ? Padding(
                                  padding: EdgeInsets.only(top: 1.h),
                                  child: Text(
                                    reason.hint,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// After sending: thanks, and the chance to block them too.
class _Sent extends StatelessWidget {
  final String name;
  final bool offerBlock;
  final VoidCallback onBlock;
  final VoidCallback onDone;

  const _Sent({
    super.key,
    required this.name,
    required this.offerBlock,
    required this.onBlock,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We’ll look into it. You don’t need to do anything else.',
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        if (offerBlock) ...[
          SizedBox(height: 10.h),
          Text(
            'If you’d rather not see $name’s snaps in the meantime, you can '
            'block them.',
            style: TextStyle(
              fontSize: 14.sp,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        SizedBox(height: 18.h),
        if (offerBlock) ...[
          SheetSecondaryButton(
            label: 'Block $name',
            icon: Icons.block_rounded,
            onPressed: onBlock,
          ),
          SizedBox(height: 10.h),
        ],
        SheetButton(label: 'Done', onPressed: onDone),
      ],
    );
  }
}
