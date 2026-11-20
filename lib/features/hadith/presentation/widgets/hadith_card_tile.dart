import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hadith.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../domain/hadith_grade.dart';
import '../../domain/hadith_search_excerpt.dart';
import '../../../../shared/widgets/translation_unavailable.dart';
import '../providers/hadith_urdu_providers.dart';

/// A hadith in a list — search results, favourites. A *preview*, so the text
/// is deliberately clipped to three lines here; the full text lives on the
/// reading screen this tile opens.
class HadithCardTile extends ConsumerWidget {
  final Hadith hadith;
  final VoidCallback onTap;

  /// The words that were searched for. The English preview is then the part of
  /// the text around the first match, with the words picked out, so a result
  /// shows why it matched.
  final List<String> highlight;

  const HadithCardTile({
    super.key,
    required this.hadith,
    required this.onTap,
    this.highlight = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
      child: PressScale(
        child: Material(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16.r),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28.w,
                        height: 28.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.hadithAccentBg,
                          borderRadius: BorderRadius.circular(9.r),
                        ),
                        child: Text(
                          '${hadith.hadithNumber}',
                          maxLines: 1,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.hadithAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          hadith.collectionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.inkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _GradePill(grade: hadith.gradeLevel, raw: hadith.grade),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  if (_urduPreview(ref) case final Widget urdu)
                    urdu
                  else if (hadith.hasTranslation)
                    _englishPreview()
                  else if (hadith.hasArabic)
                    // No translation in the source for this entry — preview the
                    // Arabic rather than showing an empty tile.
                    Text(
                      hadith.arabic,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: AppTypography.arabicBody.copyWith(
                        fontSize: 15.sp,
                        height: 1.9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placed here so [HadithCardTile] stays readable: the Urdu preview, or null
/// when English applies. With Urdu chosen this is never null: it is the Urdu,
/// a placeholder while it loads, or a message that there is none.
extension on HadithCardTile {
  /// The English preview: plain, or — for a search result — the text around
  /// the match with the searched words picked out.
  Widget _englishPreview() {
    final style = AppTypography.bodyLarge.copyWith(
      color: AppColors.textSecondary,
      height: 1.55,
    );
    if (highlight.isEmpty) {
      return Text(
        hadith.english,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final excerpt = HadithSearchExcerpt.around(hadith.english, highlight);
    return Text.rich(
      TextSpan(
        children: [
          for (final seg in HadithSearchExcerpt.segments(excerpt, highlight))
            TextSpan(
              text: seg.text,
              style: seg.match
                  ? TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkText,
                      backgroundColor: AppColors.emeraldInk.withValues(
                        alpha: 0.12,
                      ),
                    )
                  : null,
            ),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  Widget? _urduPreview(WidgetRef ref) {
    if (!ref.watch(readingPreferencesProvider.select((p) => p.isUrdu))) {
      return null;
    }
    if (!hasUrduEdition(hadith)) return _unavailable();
    final urdu = ref.watch(hadithUrduProvider(urduKeyOf(hadith)));
    if (urdu.isLoading) {
      // Hold the row's height, never flash the English.
      return SizedBox(height: 56.h);
    }
    if (urdu.hasError) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TranslationUnavailable(
          fontSize: 14.sp,
          onRetry: () => ref.invalidate(hadithUrduProvider(urduKeyOf(hadith))),
        ),
      );
    }
    final text = urdu.valueOrNull?.trim() ?? '';
    if (text.isEmpty) return _unavailable();
    return Text(
      text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'NotoNastaliqUrdu',
        fontSize: 17.sp,
        height: 2.0,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _unavailable() => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TranslationUnavailable(fontSize: 14.sp),
  );
}

class _GradePill extends StatelessWidget {
  final HadithGrade grade;
  final String raw;

  const _GradePill({required this.grade, required this.raw});

  @override
  Widget build(BuildContext context) {
    // The old tile always painted the grade in "authentic" green, whatever it
    // actually said — a weak narration read as a strong one at a glance.
    final color = switch (grade) {
      HadithGrade.sahih => AppColors.success,
      HadithGrade.hasan => AppColors.duasAccent,
      HadithGrade.daif => AppColors.error,
      HadithGrade.unknown => AppColors.textMuted,
    };
    final label = raw.trim().isEmpty ? grade.label : raw.trim();

    return Container(
      constraints: BoxConstraints(maxWidth: 96.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
