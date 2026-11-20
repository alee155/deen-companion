import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../domain/entities/search_result.dart';
import 'verse_translation_text.dart';

class SearchResultTile extends ConsumerWidget {
  final SearchResult result;
  const SearchResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.surahName} · ${result.verseKey}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.duasAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            result.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTypography.arabicBody.copyWith(
              fontSize: 18.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 8.h),
          _translation(ref),
        ],
      ),
    );
  }

  /// The result's translation in the reader's language. A result that came
  /// back from an Urdu search already is Urdu; otherwise the verse's Urdu is
  /// looked up when Urdu is chosen.
  Widget _translation(WidgetRef ref) {
    final style = AppTypography.bodyMedium.copyWith(color: AppColors.inkText);
    final isUrdu = ref.watch(
      readingPreferencesProvider.select((p) => p.isUrdu),
    );
    if (isUrdu && result.translationSource == 'urdu') {
      return Text(
        result.translation,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: VerseTranslationText.urduStyleFor(style),
      );
    }
    return VerseTranslationText(
      verseKey: result.verseKey,
      english: result.translation,
      englishStyle: style,
    );
  }
}
