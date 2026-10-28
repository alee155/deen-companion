import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../moderation_flows.dart';
import '../providers/moderation_providers.dart';

/// Confirms blocking [user]. Resolves true once they are blocked.
Future<bool?> showBlockSheet(BuildContext context, {required SafetyUser user}) {
  HapticFeedback.mediumImpact();
  return showGroupSheet<bool>(context, (_) => BlockSheet(user: user));
}

class BlockSheet extends ConsumerStatefulWidget {
  final SafetyUser user;
  const BlockSheet({super.key, required this.user});

  @override
  ConsumerState<BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends ConsumerState<BlockSheet> {
  bool _blocking = false;
  String? _error;

  Future<void> _block() async {
    if (_blocking) return;
    setState(() {
      _blocking = true;
      _error = null;
    });
    final result = await ref
        .read(blockedUsersProvider.notifier)
        .block(widget.user.toBlocked());
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => setState(() {
        _blocking = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.name;
    Widget point(IconData icon, String text) => Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: AppColors.textSecondary),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    return GroupSheetFrame(
      destructive: true,
      icon: Icons.block_rounded,
      title: 'Block $name?',
      subtitle: 'You won’t see their snaps.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          point(
            Icons.visibility_off_outlined,
            'Their snaps are hidden from you.',
          ),
          point(
            Icons.notifications_off_outlined,
            '$name isn’t told that you blocked them.',
          ),
          point(
            Icons.lock_open_rounded,
            'You can unblock them any time in Settings, under Blocked users.',
          ),
          SizedBox(height: 4.h),
          SheetNotice(message: _error),
          Row(
            children: [
              Expanded(
                child: SheetSecondaryButton(
                  label: 'Cancel',
                  onPressed: _blocking
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: SheetButton(
                  label: 'Block',
                  icon: Icons.block_rounded,
                  destructive: true,
                  loading: _blocking,
                  onPressed: _block,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
