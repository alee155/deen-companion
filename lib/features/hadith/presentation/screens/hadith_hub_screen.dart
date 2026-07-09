import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/hadith_providers.dart';
import '../widgets/hadith_book_card.dart';

class HadithHubScreen extends ConsumerWidget {
  const HadithHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(hadithCollectionsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surfaceLight,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 14.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hadith',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkText,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/hadith/search'),
                    child: Icon(
                      Icons.search,
                      color: AppColors.inkText,
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: collectionsAsync.when(
                data: (collections) => GridView.builder(
                  padding: EdgeInsets.all(20.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16.h,
                    crossAxisSpacing: 14.w,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: collections.length,
                  itemBuilder: (context, index) => HadithBookCard(
                    collection: collections[index],
                    onTap: () =>
                        context.push('/hadith/read/${collections[index].key}'),
                  ),
                ),
                loading: () => GridView.builder(
                  padding: EdgeInsets.all(20.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16.h,
                    crossAxisSpacing: 14.w,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) => ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 14.r,
                  ),
                ),
                error: (error, _) => Center(child: Text(error.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
