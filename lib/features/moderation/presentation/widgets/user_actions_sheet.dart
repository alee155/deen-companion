import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/domain/entities/group.dart';
import '../../../groups/domain/entities/group_detail.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../../../groups/presentation/widgets/snap_widgets.dart';
import '../moderation_flows.dart';

enum UserAction { report, block, unblock }

/// What the user can do about another person. Resolves to the choice, or null
/// if they dismissed it.
Future<UserAction?> showUserActionsSheet(
  BuildContext context, {
  required SafetyUser user,
  required bool isBlocked,
}) {
  HapticFeedback.selectionClick();
  return showGroupSheet<UserAction>(
    context,
    (_) => UserActionsSheet(user: user, isBlocked: isBlocked),
  );
}

class UserActionsSheet extends StatelessWidget {
  final SafetyUser user;
  final bool isBlocked;
  const UserActionsSheet({
    super.key,
    required this.user,
    required this.isBlocked,
  });

  @override
  Widget build(BuildContext context) {
    return GroupSheetFrame(
      icon: Icons.shield_outlined,
      title: user.name,
      subtitle: isBlocked ? 'You’ve blocked this person.' : 'Safety options',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemberAvatar(
                member: GroupMember(
                  userId: user.id,
                  name: user.name,
                  email: '',
                  role: GroupRole.member,
                  avatarUrl: user.avatarUrl,
                ),
                size: 44.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _ActionRow(
            icon: Icons.flag_outlined,
            title: 'Report ${user.name}',
            subtitle: 'Tell us about a problem. They won’t be told.',
            onTap: () => Navigator.of(context).pop(UserAction.report),
          ),
          SizedBox(height: 10.h),
          if (isBlocked)
            _ActionRow(
              icon: Icons.lock_open_rounded,
              title: 'Unblock ${user.name}',
              subtitle: 'You’ll see their snaps again.',
              onTap: () => Navigator.of(context).pop(UserAction.unblock),
            )
          else
            _ActionRow(
              icon: Icons.block_rounded,
              title: 'Block ${user.name}',
              subtitle: 'Hide their snaps from you.',
              destructive: true,
              onTap: () => Navigator.of(context).pop(UserAction.block),
            ),
          SizedBox(height: 14.h),
          SheetSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.inkText;
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: destructive
                  ? AppColors.error.withValues(alpha: 0.35)
                  : AppColors.borderWarm,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22.sp, color: color),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
