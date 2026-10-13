import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import '../providers/groups_providers.dart';
import 'group_sheet_widgets.dart';
import 'snap_widgets.dart';

/// Admin-only: confirm removing [member] from [group]. Resolves true once
/// they have been removed.
Future<bool?> showRemoveMemberSheet(
  BuildContext context, {
  required GroupDetail group,
  required GroupMember member,
}) {
  HapticFeedback.mediumImpact();
  return showGroupSheet<bool>(
    context,
    (_) => RemoveMemberSheet(group: group, member: member),
  );
}

class RemoveMemberSheet extends ConsumerWidget {
  final GroupDetail group;
  final GroupMember member;
  const RemoveMemberSheet({
    super.key,
    required this.group,
    required this.member,
  });

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(groupManageControllerProvider.notifier)
        .removeMember(group.id, member.userId);
    if (ok && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupManageControllerProvider);
    final removing = state.removingUserId == member.userId;

    return GroupSheetFrame(
      destructive: true,
      icon: Icons.person_remove_rounded,
      title: 'Remove member',
      subtitle: 'They’ll lose access to “${group.name}”.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              children: [
                MemberAvatar(member: member, size: 48.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                      if (member.email.isNotEmpty)
                        Text(
                          member.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                RoleBadge(role: member.role),
              ],
            ),
          ).slideIn(RevealDirection.bottom, distance: 12),
          SizedBox(height: 12.h),
          Text(
            'They can rejoin later if they have a valid invite link.',
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 14.h),
          SheetNotice(message: state.errorMessage),
          Row(
            children: [
              Expanded(
                child: SheetSecondaryButton(
                  label: 'Keep',
                  onPressed: removing
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: SheetButton(
                  label: 'Remove',
                  icon: Icons.person_remove_rounded,
                  destructive: true,
                  loading: removing,
                  onPressed: () => _remove(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
