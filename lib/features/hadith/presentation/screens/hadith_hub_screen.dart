import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../../../shared/widgets/shimmer_box.dart';
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
      appBar: DeenAppBar(
        title: 'Hadith',
        subtitle: 'The collections',
        actions: [
          IconButton(
            tooltip: 'Search hadith',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/hadith/search'),
          ),
        ],
      ),
      body: collectionsAsync.when(
        data: (collections) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _LibraryIntro(count: collections.length).appear(),
            ),
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
                      onTap: () =>
                          context.push('/hadith/read/${collection.key}'),
                    ).appearStaggered(index);
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
      ),
    );
  }
}

/// A short lead-in above the shelf, so the screen opens with a sense of place
/// rather than dropping straight into a grid.
class _LibraryIntro extends StatelessWidget {
  final int count;
  const _LibraryIntro({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Words of the Prophet ﷺ',
            style: AppTypography.heroSerif.copyWith(
              fontSize: 22.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '$count collections, with the Arabic text and its English '
            'translation side by side. Tap a book to start reading.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 16.h),
          OrnamentDivider(ruleWidth: 40.w),
        ],
      ),
    );
  }
}
