import 'package:deen_companion/features/audio_player/domain/audio_track.dart';
import 'package:deen_companion/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/quran_providers.dart';
import '../widgets/surah_list_tile.dart';

class SurahListScreen extends ConsumerWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahListAsync = ref.watch(surahListNotifierProvider);
    final metaAsync = ref.watch(quranMetaNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(surahListNotifierProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surfaceLight,
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 14.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quran',
                            style: AppTypography.greetingSerif.copyWith(
                              color: AppColors.inkText,
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.push('/quran/search'),
                                child: Icon(
                                  Icons.search,
                                  color: AppColors.inkText,
                                  size: 18.sp,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              GestureDetector(
                                onTap: () => context.push('/quran/juz'),
                                child: Icon(
                                  Icons.grid_view_outlined,
                                  color: AppColors.inkText,
                                  size: 18.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      metaAsync.when(
                        data: (meta) => Row(
                          children: [
                            _StatChip(
                              value: '${meta.totalSurahs}',
                              label: 'Surahs',
                            ),
                            SizedBox(width: 8.w),
                            _StatChip(
                              value: '${meta.totalVerses}',
                              label: 'Verses',
                            ),
                            SizedBox(width: 8.w),
                            _StatChip(value: '${meta.totalJuzs}', label: 'Juz'),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              surahListAsync.when(
                data: (surahs) => SliverList.separated(
                  itemCount: surahs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: AppColors.borderWarm),
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    return SurahListTile(
                      surah: surah,
                      onTap: () {}, // reader — next feature
                      onPlayTap: () {
                        ref
                            .read(audioPlayerNotifierProvider.notifier)
                            .playTrack(
                              AudioTrack(
                                id: 'surah-${surah.number}',
                                titleEnglish: surah.nameEnglish,
                                titleArabic: surah.nameArabic,
                                reciterName:
                                    'Mishary Rashid Alafasy', // meta's single reciter for now
                                url: surah.exampleAudioUrl,
                              ),
                            );
                        context.push('/player');
                      },
                    );
                  },
                ),
                loading: () => SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(error.toString(), textAlign: TextAlign.center),
                          SizedBox(height: 12.h),
                          ElevatedButton(
                            onPressed: () => ref
                                .read(surahListNotifierProvider.notifier)
                                .refresh(),
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
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.quranAccentBg,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.emeraldInk,
                fontSize: 15.sp,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption.copyWith(color: AppColors.inkText),
            ),
          ],
        ),
      ),
    );
  }
}
