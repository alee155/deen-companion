import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/dua_providers.dart';
import '../widgets/dua_category_card.dart';

class DuasHubScreen extends ConsumerWidget {
  const DuasHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(duasBundleNotifierProvider);

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
                    'Duas',
                    style: AppTypography.greetingSerif.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/duas/search'),
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
              child: bundleAsync.when(
                data: (bundle) => GridView.builder(
                  padding: EdgeInsets.all(20.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: bundle.categories.length,
                  itemBuilder: (context, index) {
                    final category = bundle.categories[index];
                    return DuaCategoryCard(
                      category: category,
                      onTap: () => context.push(
                        '/duas/category/${category.id}',
                        extra: category,
                      ),
                    );
                  },
                ),
                loading: () => GridView.builder(
                  padding: EdgeInsets.all(20.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: 8,
                  itemBuilder: (context, index) => ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 14.r,
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error.toString(), textAlign: TextAlign.center),
                        SizedBox(height: 12.h),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(duasBundleNotifierProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
