// import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../quran/presentation/widgets/quran_hero.dart';
import '../../domain/entities/hadith_collection.dart';
import '../providers/hadith_providers.dart';
import '../widgets/hadith_book_card.dart';

/// The hadith library: the six canonical collections and the shorter
/// anthologies, presented as a shelf of books.
class HadithHubScreen extends ConsumerWidget {
  const HadithHubScreen({super.key});

  /// Tile proportions: cover plus a three-line metadata block underneath.
  static const double _tileAspectRatio = 0.60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(hadithCollectionsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            QuranHero(
              arabicTitle: 'الحديث الشريف',
              subtitle: 'Words of the Prophet ﷺ',
              actionIcon: Icons.search_rounded,
              actionTooltip: 'Search hadith',
              onAction: () => context.push('/hadith/search'),
              stats: collectionsAsync.maybeWhen(
                data: (c) => [
                  ('${c.length}', 'Collections'),
                  (_compact(c.fold(0, (n, e) => n + e.totalHadiths)), 'Hadith'),
                  ('2', 'Languages'),
                ],
                orElse: () => const [],
              ),
            ),
            Expanded(child: _body(context, ref, collectionsAsync)),
          ],
        ),
      ),
    );
  }

  static String _compact(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<HadithCollection>> collectionsAsync,
  ) {
    return collectionsAsync.when(
      data: (collections) => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _ShelfHeading()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 14.w,
                childAspectRatio: _tileAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: collections.length,
                (context, index) {
                  final collection = collections[index];
                  return HadithBookCard(
                    collection: collection,
                    onTap: () => context.push('/hadith/read/${collection.key}'),
                  ).slideInAt(index, columns: 2, distance: 20);
                },
              ),
            ),
          ),
        ],
      ),
      loading: () => GridView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 28.h),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 14.w,
          childAspectRatio: _tileAspectRatio,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 20.r,
        ),
      ),
      error: (error, _) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: FailureView(
            failure: failureFrom(error),
            onRetry: () async =>
                ref.invalidate(hadithCollectionsNotifierProvider),
          ),
        ),
      ),
    );
  }
}

/// "The collections" label with an ornament rule, above the shelf.
class _ShelfHeading extends StatelessWidget {
  const _ShelfHeading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 14.h),
      child: Row(
        children: [
          Text(
            'The collections',
            style: AppTypography.heroSerif.copyWith(
              fontSize: 18.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(width: 12.w),
          const Expanded(child: OrnamentDivider()),
        ],
      ).slideIn(RevealDirection.topStart),
    );
  }
}
