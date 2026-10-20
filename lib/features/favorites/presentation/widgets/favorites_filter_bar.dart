import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/favorites_providers.dart';

/// Search box plus a row of category chips ("All", then each category the user
/// actually has favorites in, with its count).
class FavoritesFilterBar extends ConsumerStatefulWidget {
  const FavoritesFilterBar({super.key});

  @override
  ConsumerState<FavoritesFilterBar> createState() => _FavoritesFilterBarState();
}

class _FavoritesFilterBarState extends ConsumerState<FavoritesFilterBar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(favoritesQueryProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(favoritesQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(favoriteTypeCountsProvider);
    final selected = ref.watch(favoritesTypeFilterProvider);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final hasQuery = ref.watch(favoritesQueryProvider).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
          child: TextField(
            controller: _controller,
            onChanged: (v) =>
                ref.read(favoritesQueryProvider.notifier).state = v,
            textInputAction: TextInputAction.search,
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search your favorites',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: 20.sp,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clear,
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                        size: 18.sp,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              border: _border(AppColors.borderWarm),
              enabledBorder: _border(AppColors.borderWarm),
              focusedBorder: _border(AppColors.emeraldInk, width: 1.5),
            ),
          ),
        ),
        // One category (or none) needs no filter row.
        if (counts.length > 1) ...[
          SizedBox(height: 12.h),
          SizedBox(
            height: 38.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              children: [
                _Chip(
                  label: 'All',
                  count: total,
                  selected: selected == null,
                  onTap: () => pickFavoritesType(ref, null),
                ),
                for (final e in counts.entries)
                  _Chip(
                    label: e.key.label,
                    count: e.value,
                    selected: selected == e.key,
                    onTap: () => pickFavoritesType(ref, e.key),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onEmeraldInk : AppColors.textSecondary;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: Pressable(
        onTap: onTap,
        haptic: !selected,
        scale: 0.96,
        child: AnimatedContainer(
          duration: context.motion.duration(AppMotion.fast),
          curve: AppMotion.entrance,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: selected ? AppColors.emeraldInk : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(19.r),
            border: Border.all(
              color: selected ? AppColors.emeraldInk : AppColors.borderWarm,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: fg.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
