import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/favorite_item.dart';
import '../providers/favorites_providers.dart';
import '../widgets/favorite_category_icon.dart';
import '../widgets/favorite_row.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _query = '';

  List<FavoriteItem> _itemsOf(
    FavoriteContentType type,
    List<FavoriteItem> all,
  ) {
    final q = _query.trim().toLowerCase();
    return all
        .where(
          (item) =>
              item.type == type &&
              (q.isEmpty ||
                  item.title.toLowerCase().contains(q) ||
                  (item.subtitle ?? '').toLowerCase().contains(q)),
        )
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  void _remove(FavoriteItem item) {
    ref.read(favoritesNotifierProvider.notifier).remove(item.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed "${item.title}"'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.heroSurface,
          margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.emeraldInk,
            // toggle() re-adds it since it was just removed.
            onPressed: () =>
                ref.read(favoritesNotifierProvider.notifier).toggle(item),
          ),
        ),
      );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 20.h, 22.w, 0),
      child: Text(
        'Favorites',
        style: TextStyle(
          fontSize: 28.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.inkText,
        ),
      ).slideIn(RevealDirection.topStart),
    );
  }

  Widget _centerMessage(
    String message, {
    required IconData icon,
    VoidCallback? onRetry,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const Spacer(),
        Center(
          child: Column(
            children: [
              Container(
                height: 84.h,
                width: 84.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldInk.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: AppColors.emeraldInk, size: 36.sp),
              ).slideIn(
                RevealDirection.top,
                delay: const Duration(milliseconds: 60),
              ),
              SizedBox(height: 18.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 36.w),
                child:
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ).slideIn(
                      RevealDirection.bottom,
                      delay: const Duration(milliseconds: 130),
                    ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: 14.h),
                Pressable(
                  onTap: onRetry,
                  haptic: true,
                  child: Text(
                    'Try again',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ).slideIn(
                  RevealDirection.bottomEnd,
                  delay: const Duration(milliseconds: 200),
                ),
              ],
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildList(List<FavoriteItem> items) {
    final sections = FavoriteContentType.values
        .where((type) => _itemsOf(type, items).isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        SizedBox(height: 6.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child:
              Text(
                '${items.length} saved',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ).slideIn(
                RevealDirection.start,
                delay: const Duration(milliseconds: 70),
              ),
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search your favorites',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: 20.sp,
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: AppColors.borderWarm, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: AppColors.borderWarm, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(
                  color: AppColors.emeraldInk,
                  width: 1.5.w,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 120.h),
            children: [
              if (sections.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 60.h),
                  child: Center(
                    child: Text(
                      'No matches found',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ).slideIn(RevealDirection.bottom),
                  ),
                ),
              for (final type in sections) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(22.w, 18.h, 22.w, 6.h),
                  child: Row(
                    children: [
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inkText,
                        ),
                      ).slideIn(
                        RevealDirection.bottomStart,
                        onVisible: true,
                        key: ValueKey('fav-h-${type.name}'),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${_itemsOf(type, items).length}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emeraldInk,
                        ),
                      ).slideIn(
                        RevealDirection.topEnd,
                        onVisible: true,
                        distance: 14,
                        duration: AppMotion.normal,
                        delay: const Duration(milliseconds: 60),
                      ),
                    ],
                  ),
                ),
                ..._itemsOf(type, items).indexed.map(
                  (e) => KeyedSubtree(
                    key: ValueKey(e.$2.id),
                    child: FavoriteRow(
                      item: e.$2,
                      icon: favoriteCategoryIcon(e.$2.type),
                      iconAsset: favoriteCategoryIconAsset(e.$2.type),
                      onTap: () => context.push(e.$2.route),
                      onRemove: () => _remove(e.$2),
                    ).slideInAt(e.$1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: favoritesAsync.when(
          loading: () => const SizedBox.expand(),
          error: (_, _) => _centerMessage(
            'Could not load favorites.',
            icon: Icons.error_outline_rounded,
            onRetry: () => ref.invalidate(favoritesNotifierProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _centerMessage(
                'Tap the heart icon on a Surah, Hadith, Dua, or Name to save '
                'it here for quick access.',
                icon: Icons.favorite_border_rounded,
              );
            }
            return _buildList(items);
          },
        ),
      ),
    );
  }
}
