import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import '../providers/groups_providers.dart';
import 'group_sheet_widgets.dart';

/// Confirms leaving a group. The wording depends on who is leaving, because
/// the backend does different things: an admin hands the role to the next
/// member, and the last member leaving deletes the group. Resolves true once
/// the user has left.
Future<bool?> showLeaveGroupSheet(
  BuildContext context, {
  required GroupDetail group,
  required bool isAdmin,
}) {
  HapticFeedback.mediumImpact();
  return showGroupSheet<bool>(
    context,
    (_) => LeaveGroupSheet(group: group, isAdmin: isAdmin),
  );
}

class LeaveGroupSheet extends ConsumerWidget {
  final GroupDetail group;
  final bool isAdmin;
  const LeaveGroupSheet({
    super.key,
    required this.group,
    required this.isAdmin,
  });

  bool get _lastMember => group.memberCount <= 1;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(groupManageControllerProvider.notifier)
        .leave(group.id);
    if (ok && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupManageControllerProvider);

    final String headline;
    final List<(IconData, String)> points;
    if (_lastMember) {
      headline = 'You’re the only member';
      points = [
        (Icons.delete_forever_rounded, 'Leaving deletes “${group.name}”.'),
        (Icons.link_off_rounded, 'Its invite link stops working.'),
      ];
    } else if (isAdmin) {
      headline = 'You’re the admin';
      points = [
        (
          Icons.workspace_premium_rounded,
          'The next member becomes the admin automatically.',
        ),
        (Icons.logout_rounded, 'You’ll lose access to “${group.name}”.'),
      ];
    } else {
      headline = 'Leave “${group.name}”?';
      points = [
        (Icons.logout_rounded, 'You’ll lose access to the group.'),
        (Icons.link_rounded, 'You can rejoin later with an invite link.'),
      ];
    }

    return GroupSheetFrame(
      destructive: true,
      icon: Icons.logout_rounded,
      title: 'Leave group',
      subtitle: headline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                for (final (icon, text) in points)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 5.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 17.sp, color: AppColors.error),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              height: 1.35,
                              color: AppColors.inkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ).slideIn(RevealDirection.bottom, distance: 12),
          SizedBox(height: 16.h),
          SheetNotice(message: state.errorMessage),
          Row(
            children: [
              Expanded(
                child: SheetSecondaryButton(
                  label: 'Stay',
                  onPressed: state.isLeaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: SheetButton(
                  label: _lastMember ? 'Leave & delete' : 'Leave group',
                  icon: Icons.logout_rounded,
                  destructive: true,
                  loading: state.isLeaving,
                  onPressed: () => _leave(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
