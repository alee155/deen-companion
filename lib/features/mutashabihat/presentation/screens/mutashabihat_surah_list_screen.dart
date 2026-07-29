import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/mutashabihat_providers.dart';
import 'mutashabihat_comparison_screen.dart';

class MutashabihatSurahListScreen extends ConsumerStatefulWidget {
  final int surah;
  const MutashabihatSurahListScreen({super.key, required this.surah});

  @override
  ConsumerState<MutashabihatSurahListScreen> createState() =>
      _MutashabihatSurahListScreenState();
}

class _MutashabihatSurahListScreenState
    extends ConsumerState<MutashabihatSurahListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        ref
            .read(mutashabihatSurahPageNotifierProvider(widget.surah).notifier)
            .loadMore(widget.surah);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(
      mutashabihatSurahPageNotifierProvider(widget.surah),
    );

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Confused Verses'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: pageAsync.when(
        data: (page) {
          if (page.entries.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  'No commonly confused verses found in this surah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: page.entries.length + (page.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= page.entries.length) {
                return Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.quranAccent,
                    ),
                  ),
                );
              }
              final entry = page.entries[index];
              return InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        MutashabihatComparisonScreen(entry: entry),
                  ),
                ),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AppColors.borderWarm),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34.w,
                        height: 34.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.quranAccentBg,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          '${entry.verse.ayah}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.quranAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.verse.translation,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.inkText,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '${entry.similarVerses.length} similar verse${entry.similarVerses.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.quranAccent),
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
                  onPressed: () => ref.invalidate(
                    mutashabihatSurahPageNotifierProvider(widget.surah),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
