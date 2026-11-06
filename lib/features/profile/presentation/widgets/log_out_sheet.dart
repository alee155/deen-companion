import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';

/// Asks before logging out. Resolves true when the user confirms; Cancel,
/// close or a swipe down resolve null.
Future<bool?> showLogOutSheet(BuildContext context) =>
    showGroupSheet<bool>(context, (_) => const LogOutSheet());

class LogOutSheet extends StatelessWidget {
  const LogOutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return GroupSheetFrame(
      icon: Icons.logout_rounded,
      title: 'Log out?',
      subtitle: 'You’ll go back to browsing as a guest.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.phone_iphone_rounded,
                size: 18.sp,
                color: AppColors.emeraldInk,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Favorites and settings on this device are kept.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          SheetButton(
            label: 'Log out',
            icon: Icons.logout_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: 10.h),
          SheetSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
