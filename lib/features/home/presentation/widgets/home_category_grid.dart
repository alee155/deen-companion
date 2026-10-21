import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

class HomeCategory {
  /// Illustrated asset; a null path means [icon] is drawn instead.
  final String? iconPath;
  final IconData? icon;
  final String label;
  final String route;

  const HomeCategory({
    this.iconPath,
    this.icon,
    required this.label,
    required this.route,
  });
}

const List<HomeCategory> homeCategories = [
  HomeCategory(
    iconPath: 'assets/images/cl.png',
    label: 'Pray time',
    route: '/prayer-times',
  ),
  HomeCategory(
    iconPath: 'assets/images/quran_icon.png',
    label: 'Quran',
    route: '/quran',
  ),
  HomeCategory(
    iconPath: 'assets/images/zakat_icon.png',
    label: 'Zakat',
    route: '/zakat',
  ),
  HomeCategory(
    iconPath: 'assets/images/hadees_icon.png',
    label: 'Hadith',
    route: '/hadith',
  ),
  HomeCategory(
    iconPath: 'assets/images/dua_icon.png',
    label: 'Duas',
    route: '/duas',
  ),
  HomeCategory(
    iconPath: 'assets/images/compass.png',
    label: 'Qibla',
    route: '/qibla',
  ),
  HomeCategory(
    iconPath: 'assets/images/calendar_icon.png',
    label: 'Calendar',
    route: '/islamic-calendar',
  ),
  // Always last: the rest of the features.
  HomeCategory(icon: Icons.grid_view_rounded, label: 'More', route: '/explore'),
];

/// Two rows of four quick-access category cards under Home's slider header,
/// the last one being "More". Purely
/// presentational — routing and the "which one is highlighted" state live
/// with the caller.
class HomeCategoryGrid extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const HomeCategoryGrid({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _columns = 4;

  @override
  Widget build(BuildContext context) {
    final rows = (homeCategories.length / _columns).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var c = 0; c < _columns; c++) _cell(r * _columns + c),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(int index) {
    if (index >= homeCategories.length) return SizedBox(width: 62.h);
    return _CategoryCard(
      data: homeCategories[index],
      isSelected: selectedIndex == index,
      onTap: () => onSelected(index),
    ).slideInAt(index, columns: _columns, distance: 18);
  }
}

class _CategoryCard extends StatelessWidget {
  final HomeCategory data;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: context.motion.duration(AppMotion.fast),
            curve: AppMotion.entrance,
            height: 62.h,
            width: 62.h,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.inkText : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: isSelected ? AppColors.inkText : AppColors.borderWarm,
                width: 1.2.w,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: data.iconPath != null
                  ? Image.asset(data.iconPath!, fit: BoxFit.contain)
                  : Icon(
                      data.icon,
                      size: 26.sp,
                      color: isSelected
                          ? AppColors.surfaceLight
                          : AppColors.inkText,
                    ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.inkText : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
