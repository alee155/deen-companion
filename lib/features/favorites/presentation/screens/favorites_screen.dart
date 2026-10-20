import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../domain/entities/favorite_item.dart';
import '../providers/favorites_providers.dart';
import '../widgets/favorite_category_icon.dart';
import '../widgets/favorite_row.dart';
import '../widgets/favorites_filter_bar.dart';
import '../widgets/favorites_message.dart';

/// Everything the user has saved, in one place: a hero with the totals, search
/// and category chips, then the favorites as cards (grouped by category under
/// "All", flat under a single category).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  void _remove(BuildContext context, WidgetRef ref, FavoriteItem item) {
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

  Widget _hero(List<FavoriteItem> all, Map<FavoriteContentType, int> counts) {
    final n = all.length;
    return FeatureHero(
      title: 'Favorites',
      subtitle: n == 0
          ? 'Save Surahs, Hadith, Duas and Names to find them here'
          : 'Everything you\'ve saved, in one place',
      ghostIcon: Icons.favorite_rounded,
      chips: [
        FeatureHeroChip(Icons.favorite_rounded, '$n saved'),
        if (counts.length > 1)
          FeatureHeroChip(
            Icons.category_outlined,
            '${counts.length} categories',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesNotifierProvider);
    final all = async.valueOrNull ?? const <FavoriteItem>[];
    final counts = ref.watch(favoriteTypeCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _hero(all, counts)),
          if (async.hasError && !async.hasValue)
            SliverToBoxAdapter(
              child: FavoritesMessage(
                icon: Icons.error_outline_rounded,
                title: 'Could not load favorites',
                message: 'Something went wrong reading your saved items.',
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(favoritesNotifierProvider),
              ),
            )
          else if (async.isLoading && !async.hasValue)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (all.isEmpty)
            SliverToBoxAdapter(
              child: FavoritesMessage(
                icon: Icons.favorite_border_rounded,
                title: 'No favorites yet',
                message:
                    'Tap the heart on a Surah, Hadith, Dua or Name to save it '
                    'here for quick access.',
                actionLabel: 'Explore',
                onAction: () => context.push('/explore'),
              ),
            )
          else ...[
            const SliverToBoxAdapter(child: FavoritesFilterBar()),
            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
            _FavoritesList(onRemove: (item) => _remove(context, ref, item)),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 120.h)),
        ],
      ),
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  final void Function(FavoriteItem item) onRemove;
  const _FavoritesList({required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleFavoritesProvider);
    final type = ref.watch(favoritesTypeFilterProvider);

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: FavoritesMessage(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message: 'Nothing in your favorites matches that search.',
        ),
      );
    }

    // Under "All", a heading precedes each category's cards.
    final entries = <Object>[];
    if (type == null) {
      for (final t in FavoriteContentType.values) {
        final inType = items.where((i) => i.type == t).toList();
        if (inType.isEmpty) continue;
        entries
          ..add(t)
          ..addAll(inType);
      }
    } else {
      entries.addAll(items);
    }

    var cardIndex = 0;
    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        if (entry is FavoriteContentType) {
          final count = items.where((x) => x.type == entry).length;
          return _SectionHeading(type: entry, count: count);
        }
        final item = entry as FavoriteItem;
        return KeyedSubtree(
          key: ValueKey(item.id),
          child: FavoriteRow(
            item: item,
            icon: favoriteCategoryIcon(item.type),
            iconAsset: favoriteCategoryIconAsset(item.type),
            onTap: () => context.push(item.route),
            onRemove: () => onRemove(item),
          ).slideInAt(cardIndex++),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final FavoriteContentType type;
  final int count;
  const _SectionHeading({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 14.h, 24.w, 8.h),
      child: Row(
        children: [
          Text(
            type.label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppColors.emeraldInk.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
