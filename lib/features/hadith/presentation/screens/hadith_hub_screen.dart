import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/hadith_providers.dart';
import '../widgets/hadith_card_tile.dart';
import '../widgets/hadith_collection_picker_sheet.dart';

class HadithHubScreen extends ConsumerStatefulWidget {
  const HadithHubScreen({super.key});

  @override
  ConsumerState<HadithHubScreen> createState() => _HadithHubScreenState();
}

class _HadithHubScreenState extends ConsumerState<HadithHubScreen> {
  String _selectedCollection = 'bukhari';
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        ref
            .read(hadithListNotifierProvider(_selectedCollection).notifier)
            .loadMore(_selectedCollection);
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
    final collectionsAsync = ref.watch(hadithCollectionsNotifierProvider);
    final listState = ref.watch(
      hadithListNotifierProvider(_selectedCollection),
    );

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
                    style: AppTypography.greetingSerif.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                  Row(
                    children: [
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
                ],
              ),
            ),
            collectionsAsync.when(
              data: (collections) {
                final selected = collections.firstWhere(
                  (c) => c.key == _selectedCollection,
                  orElse: () => collections.first,
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showHadithCollectionPicker(
                        context,
                        collections: collections,
                        selectedKey: _selectedCollection,
                      );
                      if (picked != null)
                        setState(() => _selectedCollection = picked);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.borderWarm),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${selected.name} · ${selected.totalHadiths} hadiths',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.inkText,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                            size: 18.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => SizedBox(height: 40.h),
              error: (_, __) => const SizedBox.shrink(),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: listState.when(
                data: (state) => ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(bottom: 20.h),
                  itemCount: state.hadiths.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.hadiths.length) {
                      return Padding(
                        padding: EdgeInsets.all(20.w),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.emeraldInk,
                          ),
                        ),
                      );
                    }
                    final hadith = state.hadiths[index];
                    return HadithCardTile(
                      hadith: hadith,
                      onTap: () =>
                          context.push('/hadith/detail', extra: hadith),
                    );
                  },
                ),
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.emeraldInk),
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
                            hadithListNotifierProvider(_selectedCollection),
                          ),
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
