import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../motion/motion.dart';
import '../theme/app_colors.dart';

/// Dark floating pill nav bar from the new design system. Not wired into
/// [AppShell] yet — the current shell has a different tab set (Home /
/// Favorites / Recent Activity / Profile) than this component's (Home /
/// Favorites / Settings / Profile). Kept here, ready for when the shell's
/// tabs get redesigned too.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
      child: Container(
        height: 68.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: AppColors.heroSurface,
          borderRadius: BorderRadius.circular(35.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (index) {
            final isSelected = currentIndex == index;
            return _NavItem(
              data: items[index],
              isSelected: isSelected,
              onTap: () => onTap(index),
            ).slideInAt(index, columns: items.length, distance: 16);
          }),
        ),
      ),
    );
  }
}

class FloatingNavItem {
  final IconData icon;
  final String label;

  const FloatingNavItem({required this.icon, required this.label});
}

class _NavItem extends StatelessWidget {
  final FloatingNavItem data;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return Pressable(
      onTap: () {
        if (!isSelected) AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: motion.duration(AppMotion.normal),
        curve: AppMotion.entrance,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.w : 12.w,
          vertical: 10.h,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emeraldInk : Colors.transparent,
          borderRadius: BorderRadius.circular(25.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 22.sp,
              color: isSelected ? AppColors.onHeroSurface : AppColors.textMuted,
            ),
            AnimatedSize(
              duration: motion.duration(AppMotion.normal),
              curve: AppMotion.entrance,
              child: isSelected
                  ? Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: Text(
                        data.label,
                        style: TextStyle(
                          color: AppColors.onHeroSurface,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
