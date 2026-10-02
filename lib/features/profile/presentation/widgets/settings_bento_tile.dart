import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// A single "bento box" tile in the new Settings layout — a flat-colored
/// card that's optionally tappable, used for both stat-style tiles (dark
/// background, big value) and plain content tiles.
class SettingsBentoTile extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final bool bordered;

  const SettingsBentoTile({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.height,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16.r),
          border: bordered ? Border.all(color: AppColors.borderWarm) : null,
        ),
        child: child,
      ),
    );
  }
}
