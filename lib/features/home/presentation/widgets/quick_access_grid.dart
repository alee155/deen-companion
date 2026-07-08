import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class QuickAccessItem {
  final String label;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;
  final VoidCallback onTap;

  const QuickAccessItem({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
    required this.onTap,
  });
}

class QuickAccessGrid extends StatelessWidget {
  final List<QuickAccessItem> items;
  const QuickAccessGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 0.72,
      children: items.map((item) {
        return GestureDetector(
          onTap: item.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(
                  color: item.accentBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(item.icon, color: item.accentColor, size: 19.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.inkText),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
