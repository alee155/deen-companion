import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import '../providers/groups_providers.dart';
import 'group_sheet_widgets.dart';

/// Admin-only. Resolves true once the group is deleted.
Future<bool?> showDeleteGroupSheet(BuildContext context, GroupDetail group) {
  HapticFeedback.mediumImpact();
  return showGroupSheet<bool>(context, (_) => DeleteGroupSheet(group: group));
}

class DeleteGroupSheet extends ConsumerStatefulWidget {
  final GroupDetail group;
  const DeleteGroupSheet({super.key, required this.group});

  @override
  ConsumerState<DeleteGroupSheet> createState() => _DeleteGroupSheetState();
}

class _DeleteGroupSheetState extends ConsumerState<DeleteGroupSheet> {
  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(groupManageControllerProvider.notifier)
        .delete(widget.group.id);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupManageControllerProvider);
    final g = widget.group;
    final members = g.memberCount;

    Widget consequence(IconData icon, String text) => Padding(
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
    );

    return GroupSheetFrame(
      destructive: true,
      icon: Icons.delete_forever_rounded,
      title: 'Delete group',
      subtitle: 'This can’t be undone.',
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
                consequence(
                  Icons.groups_rounded,
                  '“${g.name}” is removed for all $members '
                  '${members == 1 ? 'member' : 'members'}.',
                ),
                consequence(
                  Icons.local_fire_department_rounded,
                  'Its streaks and activity are lost.',
                ),
                consequence(
                  Icons.link_off_rounded,
                  'The invite link stops working.',
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
                  label: 'Keep group',
                  onPressed: state.isDeleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: SheetButton(
                  label: 'Delete group',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  loading: state.isDeleting,
                  onPressed: _delete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
