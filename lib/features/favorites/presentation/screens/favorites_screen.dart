import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../ads/presentation/widgets/banner_ad_widget.dart';
import '../../domain/entities/favorite_item.dart';
import '../providers/favorites_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  IconData _iconFor(FavoriteContentType type) {
    switch (type) {
      case FavoriteContentType.surah:
        return Icons.menu_book_outlined;
      case FavoriteContentType.hadith:
        return Icons.format_quote;
      case FavoriteContentType.dua:
        return Icons.volunteer_activism_outlined;
      case FavoriteContentType.asmaName:
        return Icons.auto_awesome_outlined;
      case FavoriteContentType.islamicName:
        return Icons.badge_outlined;
      case FavoriteContentType.juz:
        return Icons.bookmark_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: favoritesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => Center(
                  child: Text(
                    'Could not load favorites.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                data: (favorites) {
                  if (favorites.isEmpty) {
                    return ListView(
                      padding: EdgeInsets.all(20.w),
                      children: [
                        Text(
                          'Favorites',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        _EmptyCard(
                          icon: Icons.favorite_border,
                          message:
                              'Tap the heart icon on a Surah, Hadith, Dua, or Name '
                              'to save it here for quick access.',
                        ),
                      ],
                    );
                  }

                  final grouped = <FavoriteContentType, List<FavoriteItem>>{};
                  for (final item in favorites) {
                    grouped.putIfAbsent(item.type, () => []).add(item);
                  }

                  return ListView(
                    padding: EdgeInsets.all(20.w),
                    children: [
                      Text(
                        'Favorites',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      for (final type in grouped.keys) ...[
                        _SectionHeader(title: type.label),
                        ...grouped[type]!.asMap().entries.map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: _FavoriteTile(
                              item: entry.value,
                              icon: _iconFor(type),
                              onTap: () => context.push(entry.value.route),
                              onRemove: () => ref
                                  .read(favoritesNotifierProvider.notifier)
                                  .remove(entry.value.id),
                            ).appearStaggered(entry.key),
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                    ],
                  );
                },
              ),
            ),
            // Pinned below the list rather than inside it: stays visible
            // regardless of loading/error/empty/data state, and doesn't
            // shift position as favorites are added or removed.
            const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.inkText,
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final FavoriteItem item;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteTile({
    required this.item,
    required this.icon,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          color: AppColors.hadithAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.hadithAccent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20.sp, color: AppColors.emeraldInk),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkText,
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          item.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18.sp,
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

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32.sp, color: AppColors.textMuted),
          SizedBox(height: 10.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
