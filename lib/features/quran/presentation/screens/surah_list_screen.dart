import 'package:deen_companion/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/last_read_surah_provider.dart';
import '../providers/quran_providers.dart';
import '../providers/surah_playback.dart';
import '../widgets/last_read_card.dart';
import '../widgets/surah_card_tile.dart';

class SurahListScreen extends ConsumerWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahListAsync = ref.watch(surahListNotifierProvider);
    final lastRead = ref.watch(lastReadSurahProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,

      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Quran',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(surahListNotifierProvider.notifier).refresh(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lastRead != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: LastReadCard(
                    surah: lastRead,
                    onContinue: () {
                      playSurah(ref, lastRead);
                      context.push('/player');
                    },
                  ),
                ),
              ],

              SizedBox(height: 8.h),

              Expanded(
                child: surahListAsync.when(
                  data: (surahs) => ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];

                      return SurahCardTile(
                        surah: surah,
                        onTap: () {
                          playSurah(ref, surah);
                          context.push('/player');
                        },
                      ).slideInAt(index);
                    },
                  ),
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.emeraldInk,
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                          ).slideIn(RevealDirection.top),
                          SizedBox(height: 12.h),
                          ElevatedButton(
                            onPressed: () => ref
                                .read(surahListNotifierProvider.notifier)
                                .refresh(),
                            child: const Text('Try again'),
                          ).slideIn(
                            RevealDirection.bottom,
                            delay: const Duration(milliseconds: 80),
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
      ),
    );
  }
}
