import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/hadith_providers.dart';
import '../widgets/hadith_collection_picker_sheet.dart';

class HadithReadingScreen extends ConsumerStatefulWidget {
  final String collectionKey;
  const HadithReadingScreen({super.key, required this.collectionKey});

  @override
  ConsumerState<HadithReadingScreen> createState() =>
      _HadithReadingScreenState();
}

class _HadithReadingScreenState extends ConsumerState<HadithReadingScreen> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, dynamic state) {
    // setState only happens once per actual page change (PageView's own
    // onPageChanged callback), not on every scroll pixel — this is the
    // fix for the performance issue the old page-curl reader had.
    setState(() => _page = index);
    if (index >= state.hadiths.length - 3 &&
        state.hasMore &&
        !state.isLoadingMore) {
      ref
          .read(hadithListNotifierProvider(widget.collectionKey).notifier)
          .loadMore(widget.collectionKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(
      hadithListNotifierProvider(widget.collectionKey),
    );

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
        title: listState.value != null
            ? Text(
                '${_page + 1} / ${listState.value!.hadiths.length}${listState.value!.hasMore ? '+' : ''}',
              )
            : const Text('Hadith'),
      ),
      body: listState.when(
        data: (state) {
          if (state.hadiths.isEmpty) {
            return Center(
              child: Text(
                'No hadiths found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return Column(
            children: [
              LinearProgressIndicator(
                value: (_page + 1) / state.hadiths.length,
                backgroundColor: AppColors.borderWarm,
                color: AppColors.hadithAccent,
                minHeight: 3.h,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: state.hadiths.length,
                  onPageChanged: (i) => _onPageChanged(i, state),
                  itemBuilder: (context, index) {
                    final hadith = state.hadiths[index];
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.hadithAccentBg,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  'Hadith ${hadith.hadithNumber}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.hadithAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                hadith.grade,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Icon(
                                Icons.bookmark_outline,
                                size: 18.sp,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                          SizedBox(height: 28.h),
                          Text(
                            hadith.arabic,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 20.sp,
                              height: 2.0,
                              color: AppColors.inkText,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Divider(color: AppColors.borderWarm),
                          SizedBox(height: 24.h),
                          Text(
                            hadith.english,
                            style: TextStyle(
                              fontSize: 15.sp,
                              height: 1.7,
                              color: AppColors.inkText,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _page > 0
                          ? () => _controller.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            )
                          : null,
                    ),
                    Text(
                      'Swipe or tap to continue',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              ShimmerBox(width: double.infinity, height: 3.h),
              SizedBox(height: 28.h),
              ShimmerBox(
                width: double.infinity,
                height: 100.h,
                borderRadius: 8.r,
              ),
              SizedBox(height: 24.h),
              ShimmerBox(
                width: double.infinity,
                height: 120.h,
                borderRadius: 8.r,
              ),
            ],
          ),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
