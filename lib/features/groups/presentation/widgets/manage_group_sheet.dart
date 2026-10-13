import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import 'group_sheet_widgets.dart';

enum ManageAction { edit, invite, leave, delete }

/// Group options. Admins get edit/delete too; everyone can share the invite
/// link and leave.
Future<ManageAction?> showManageGroupSheet(
  BuildContext context,
  GroupDetail group, {
  required bool isAdmin,
}) {
  HapticFeedback.selectionClick();
  return showGroupSheet<ManageAction>(
    context,
    (_) => GroupSheetFrame(
      icon: Icons.tune_rounded,
      title: isAdmin ? 'Manage group' : 'Group options',
      subtitle: group.name,
      child: Builder(
        builder: (ctx) => Column(
          children: [
            if (isAdmin) ...[
              _ActionTile(
                icon: Icons.edit_rounded,
                color: AppColors.emeraldInk,
                bg: AppColors.emeraldInk.withValues(alpha: 0.16),
                title: 'Edit details',
                subtitle: 'Change the name and description',
                onTap: () => Navigator.of(ctx).pop(ManageAction.edit),
              ).slideIn(RevealDirection.bottom, distance: 14),
              SizedBox(height: 10.h),
            ],
            _ActionTile(
              icon: Icons.link_rounded,
              color: AppColors.worshipAccent,
              bg: AppColors.worshipAccentBg,
              title: 'Invite link',
              subtitle: isAdmin
                  ? 'Share or reset the link to join'
                  : 'Share the link to join',
              onTap: () => Navigator.of(ctx).pop(ManageAction.invite),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 50),
              distance: 14,
            ),
            SizedBox(height: 10.h),
            _ActionTile(
              icon: Icons.logout_rounded,
              color: AppColors.error,
              bg: AppColors.error.withValues(alpha: 0.12),
              title: 'Leave group',
              subtitle: isAdmin
                  ? 'The next member becomes admin'
                  : 'You can rejoin with an invite link',
              destructive: true,
              onTap: () => Navigator.of(ctx).pop(ManageAction.leave),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 100),
              distance: 14,
            ),
            if (isAdmin) ...[
              SizedBox(height: 10.h),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                color: AppColors.error,
                bg: AppColors.error.withValues(alpha: 0.12),
                title: 'Delete group',
                subtitle: 'Permanently remove it for everyone',
                destructive: true,
                onTap: () => Navigator.of(ctx).pop(ManageAction.delete),
              ).slideIn(
                RevealDirection.bottom,
                delay: const Duration(milliseconds: 150),
                distance: 14,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: destructive
                    ? AppColors.error.withValues(alpha: 0.35)
                    : AppColors.borderWarm,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(icon, size: 20.sp, color: color),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: destructive
                              ? AppColors.error
                              : AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 1.h),
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
      ),
    );
  }
}
