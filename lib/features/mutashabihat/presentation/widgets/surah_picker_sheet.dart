import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../quran/domain/entities/surah_summary.dart';
import '../../../quran/presentation/providers/quran_providers.dart';

/// Returns the chosen [SurahSummary] (not just its number) so callers get the
/// name and verse count for free — the ayah picker that usually follows this
/// sheet needs the verse count to know how many ayahs to offer.
Future<SurahSummary?> showSurahPickerSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<SurahSummary>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => const _SurahPickerContent(),
  );
}

class _SurahPickerContent extends ConsumerStatefulWidget {
  const _SurahPickerContent();

  @override
  ConsumerState<_SurahPickerContent> createState() =>
      _SurahPickerContentState();
}

class _SurahPickerContentState extends ConsumerState<_SurahPickerContent> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final surahsAsync = ref.watch(surahListNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.borderWarm,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'Choose a surah',
                style: AppTypography.headline.copyWith(
                  fontSize: 16.sp,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search surah…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                    size: 20.sp,
                  ),
                  filled: true,
                  fillColor: AppColors.parchment,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: surahsAsync.when(
                  data: (surahs) {
                    final filtered = _query.isEmpty
                        ? surahs
                        : surahs
                              .where(
                                (s) => s.nameEnglish.toLowerCase().contains(
                                  _query,
                                ),
                              )
                              .toList();
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.borderWarm),
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.quranAccentBg,
                            child: Text(
                              '${s.number}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.quranAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            s.nameEnglish,
                            style: TextStyle(
                              color: AppColors.inkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${s.nameTranslation} · ${s.versesCount} verses',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.emeraldInk,
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Text(
                      error.toString(),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
