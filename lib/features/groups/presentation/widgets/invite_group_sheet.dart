import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/share_text.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/group_detail.dart';
import '../providers/groups_providers.dart';
import 'group_sheet_widgets.dart';

/// Shows the group's invite link (copy / share). Admins can also reset it.
/// The link always belongs to [group] — its id comes from the API.
Future<void> showInviteGroupSheet(
  BuildContext context, {
  required GroupDetail group,
  required bool isAdmin,
}) {
  return showGroupSheet<void>(
    context,
    (_) => InviteGroupSheet(group: group, isAdmin: isAdmin),
  );
}

class InviteGroupSheet extends ConsumerStatefulWidget {
  final GroupDetail group;
  final bool isAdmin;
  const InviteGroupSheet({
    super.key,
    required this.group,
    required this.isAdmin,
  });

  @override
  ConsumerState<InviteGroupSheet> createState() => _InviteGroupSheetState();
}

class _InviteGroupSheetState extends ConsumerState<InviteGroupSheet> {
  bool _confirmingReset = false;
  String? _error;
  String? _success;

  Future<void> _reset() async {
    setState(() {
      _error = null;
      _success = null;
    });
    final error = await ref
        .read(groupInviteProvider(widget.group.id).notifier)
        .reset();
    if (!mounted) return;
    setState(() {
      _confirmingReset = false;
      _error = error;
      _success = error == null
          ? 'New link created. The old one no longer works.'
          : null;
    });
    if (error == null) HapticFeedback.mediumImpact();
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      _error = null;
      _success = 'Link copied';
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupInviteProvider(widget.group.id));
    final invite = async.valueOrNull;
    final resetting = async.isLoading && invite != null;

    return GroupSheetFrame(
      icon: Icons.link_rounded,
      title: 'Invite link',
      subtitle: 'Anyone with this link can join “${widget.group.name}”.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (invite == null && async.isLoading)
            ShimmerBox(width: double.infinity, height: 92.h, borderRadius: 20.r)
          else if (invite == null)
            _LoadError(
              message: async.error?.toString() ?? 'Couldn’t load the link.',
              onRetry: () =>
                  ref.invalidate(groupInviteProvider(widget.group.id)),
            )
          else ...[
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: resetting ? 0.45 : 1,
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.emeraldInk.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 14.sp,
                          color: AppColors.emeraldInk,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'INVITE CODE',
                          style: TextStyle(
                            fontSize: 9.sp,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          invite.token,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(a),
                          child: c,
                        ),
                      ),
                      child: SelectableText(
                        invite.url,
                        key: ValueKey(invite.url),
                        style: TextStyle(
                          fontSize: 13.sp,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).slideIn(RevealDirection.bottom, distance: 12),
            SizedBox(height: 12.h),
            SheetNotice(message: _error ?? _success, success: _error == null),
            Row(
              children: [
                Expanded(
                  child: SheetSecondaryButton(
                    label: 'Copy',
                    icon: Icons.copy_rounded,
                    onPressed: resetting ? null : () => _copy(invite.url),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SheetButton(
                    label: 'Share',
                    icon: Icons.ios_share_rounded,
                    onPressed: resetting
                        ? null
                        : () => shareText(
                            context,
                            'Join “${widget.group.name}” on Deen Companion: '
                            '${invite.url}',
                          ),
                  ),
                ),
              ],
            ),
            if (widget.isAdmin) ...[
              SizedBox(height: 16.h),
              Divider(height: 1, color: AppColors.borderWarm),
              SizedBox(height: 12.h),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _confirmingReset
                    ? _ResetConfirm(
                        key: const ValueKey('confirm'),
                        loading: resetting,
                        onCancel: () =>
                            setState(() => _confirmingReset = false),
                        onConfirm: _reset,
                      )
                    : TextButton.icon(
                        key: const ValueKey('reset'),
                        onPressed: resetting
                            ? null
                            : () => setState(() {
                                _confirmingReset = true;
                                _success = null;
                                _error = null;
                              }),
                        icon: Icon(Icons.autorenew_rounded, size: 18.sp),
                        label: Text(
                          'Reset invite link',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResetConfirm extends StatelessWidget {
  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ResetConfirm({
    super.key,
    required this.loading,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset the link? The current one stops working right away, so '
          'anyone you already shared it with will need the new link.',
          style: TextStyle(
            fontSize: 12.5.sp,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: SheetSecondaryButton(
                label: 'Cancel',
                onPressed: loading ? null : onCancel,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: SheetButton(
                label: 'Reset link',
                icon: Icons.autorenew_rounded,
                destructive: true,
                loading: loading,
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SheetNotice(message: message),
        SheetButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
