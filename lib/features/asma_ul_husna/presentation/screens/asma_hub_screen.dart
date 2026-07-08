import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../providers/asma_ul_husna_providers.dart';
import '../screens/asma_daily_practice_screen.dart';
import '../screens/asma_detail_screen.dart';
import '../widgets/asma_name_tile.dart';

class AsmaHubScreen extends ConsumerWidget {
  const AsmaHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final namesAsync = ref.watch(asmaAllNamesNotifierProvider);
    final today =
        DateTime.now().weekday; // 1 = Monday ... 7 = Sunday, matches API

    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => context.push('/asma-ul-husna/search'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    children: [
                      Text(
                        'أسماء الله الحسنى',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 26.sp,
                          color: AppColors.inkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'The 99 Beautiful Names of Allah',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AsmaDailyPracticeScreen(initialDay: today),
                      ),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldInk,
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today\'s Dhikr',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.gold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'Recite today\'s 15 names',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Complete all 99 across the week',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44.w,
                            height: 44.w,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: AppColors.emeraldInk,
                              size: 22.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              namesAsync.when(
                data: (names) => SliverPadding(
                  padding: EdgeInsets.all(20.w),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16.h,
                      crossAxisSpacing: 8.w,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AsmaNameTile(
                        name: names[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AsmaDetailScreen(
                              names: names,
                              initialIndex: index,
                            ),
                          ),
                        ),
                      ),
                      childCount: names.length,
                    ),
                  ),
                ),
                loading: () => SliverPadding(
                  padding: EdgeInsets.all(20.w),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16.h,
                      crossAxisSpacing: 8.w,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ShimmerBox(
                        width: 62.w,
                        height: 62.w,
                        borderRadius: 31.r,
                      ),
                      childCount: 20,
                    ),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Center(child: Text(error.toString())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
