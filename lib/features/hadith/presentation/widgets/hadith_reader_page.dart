import 'package:deen_companion/shared/providers/reading_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/hadith_grade.dart';

/// One hadith, laid out as a page in the reader.
///
/// The whole page is one scroll view with a constrained measure: text never
/// stretches past a comfortable reading width on a tablet, and nothing is
/// ever clipped or line-limited — the full Arabic and the full translation
/// are always rendered, however long they run.
class HadithReaderPage extends StatelessWidget {
  final Hadith hadith;
  final HadithCollection? collection;
  final ReadingPreferences preferences;

  /// Position within the loaded list, shown as "3 of 50+". Omitted when the
  /// page stands alone (opened from search, or from Favorites), where there is
  /// no list to be positioned in.
  final int? position;
  final int? total;
  final bool hasMore;

  /// Tapping the body toggles the reader's chrome. Optional — a standalone
  /// page has no chrome to hide.
  final VoidCallback? onTapBody;

  const HadithReaderPage({
    super.key,
    required this.hadith,
    required this.collection,
    required this.preferences,
    this.position,
    this.total,
    this.hasMore = false,
    this.onTapBody,
  });

  /// Roughly 66 characters at the default size — the width prose stays
  /// comfortable to read at. Beyond this the eye loses the line on return.
  static const double _measure = 620;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapBody,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 28.h),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _measure),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageMeta(
                    hadith: hadith,
                    position: position,
                    total: total,
                    hasMore: hasMore,
                  ),
                  SizedBox(height: 20.h),

                  if (preferences.showArabic && hadith.hasArabic) ...[
                    _ArabicPanel(
                      text: hadith.arabic,
                      style: preferences.arabicStyle,
                    ),
                    if (preferences.showTranslation) SizedBox(height: 22.h),
                  ],

                  if (preferences.showTranslation) ...[
                    if (preferences.showArabic && hadith.hasArabic) ...[
                      OrnamentDivider(ruleWidth: 46.w),
                      SizedBox(height: 20.h),
                    ],
                    _TranslationBlock(
                      hadith: hadith,
                      style: preferences.englishStyle,
                    ),
                  ],

                  SizedBox(height: 26.h),
                  _Attribution(hadith: hadith, collection: collection),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hadith number, grade, and where you are in the collection.
class _PageMeta extends StatelessWidget {
  final Hadith hadith;
  final int? position;
  final int? total;
  final bool hasMore;

  const _PageMeta({
    required this.hadith,
    required this.position,
    required this.total,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NumberMedallion(number: hadith.hadithNumber),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hadith ${hadith.hadithNumber}',
                style: AppTypography.headline.copyWith(
                  fontSize: 15.sp,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                position == null || total == null
                    ? hadith.collectionName
                    : '$position of $total${hasMore ? '+' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        _GradeBadge(grade: hadith.gradeLevel, raw: hadith.grade),
      ],
    );
  }
}

/// The hadith number set in a soft rounded medallion — gives each page an
/// anchor and makes flicking through feel like turning numbered pages.
class _NumberMedallion extends StatelessWidget {
  final int number;
  const _NumberMedallion({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.w,
      height: 42.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.hadithAccentBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.hadithAccent.withValues(alpha: .2)),
      ),
      child: Text(
        '$number',
        maxLines: 1,
        style: AppTypography.headline.copyWith(
          fontSize: number > 999 ? 12.sp : 14.sp,
          color: AppColors.hadithAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final HadithGrade grade;
  final String raw;

  const _GradeBadge({required this.grade, required this.raw});

  Color get _color => switch (grade) {
    HadithGrade.sahih => AppColors.success,
    HadithGrade.hasan => AppColors.duasAccent,
    HadithGrade.daif => AppColors.error,
    HadithGrade.unknown => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    // Prefer the source's own wording (it sometimes names the grader), and
    // fall back to the parsed level when the field is blank.
    final label = raw.trim().isEmpty ? grade.label : raw.trim();

    return Tooltip(
      message: 'Authenticity grading: $label',
      child: Container(
        constraints: BoxConstraints(maxWidth: 130.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: _color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Arabic text, on its own tinted panel so the eye reads it as the
/// primary object on the page rather than as one paragraph among several.
class _ArabicPanel extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _ArabicPanel({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
      decoration: BoxDecoration(
        color: AppColors.isDark
            ? AppColors.surfaceLight
            : AppColors.hijriAccentBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Semantics(
        label: 'Arabic text of the hadith',
        child: AnimatedDefaultTextStyle(
          // Font-size changes from the slider ease in instead of snapping.
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: style.copyWith(color: AppColors.inkText),
          child: SelectableText(
            text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            style: style.copyWith(color: AppColors.inkText),
          ),
        ),
      ),
    );
  }
}

class _TranslationBlock extends StatelessWidget {
  final Hadith hadith;
  final TextStyle style;

  const _TranslationBlock({required this.hadith, required this.style});

  @override
  Widget build(BuildContext context) {
    if (!hadith.hasTranslation) return const _MissingTranslationNote();

    final text = hadith.english.trim();
    // The dataset marks the narrator with a leading "Narrated X:" — pulling it
    // out as its own line gives the translation a proper opening instead of a
    // wall of text.
    final narratorMatch = RegExp(r'^(Narrated[^:]{0,80}:)\s*').firstMatch(text);
    final narrator = narratorMatch?.group(1);
    final body = narrator == null ? text : text.substring(narratorMatch!.end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.translate_rounded,
              size: 13.sp,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              'TRANSLATION',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        if (narrator != null) ...[
          Text(
            narrator,
            style: style.copyWith(
              color: AppColors.hadithAccent,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        Semantics(
          label: 'English translation of the hadith',
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: style.copyWith(color: AppColors.inkText),
            child: SelectableText(
              body,
              textAlign: TextAlign.start,
              style: style.copyWith(color: AppColors.inkText),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown for the handful of entries the source dataset ships without an
/// English translation. Saying so is better than an unexplained blank.
class _MissingTranslationNote extends StatelessWidget {
  const _MissingTranslationNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.toolsAccentBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16.sp,
            color: AppColors.toolsAccent,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'No English translation is available for this hadith in our '
              'source. The Arabic text above is complete.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  final Hadith hadith;
  final HadithCollection? collection;

  const _Attribution({required this.hadith, required this.collection});

  @override
  Widget build(BuildContext context) {
    final name = collection?.name.isNotEmpty == true
        ? collection!.name
        : hadith.collectionName;
    final author = collection?.author;

    return Column(
      children: [
        OrnamentDivider(ruleWidth: 30.w),
        SizedBox(height: 12.h),
        Text(
          '$name · Hadith ${hadith.hadithNumber}',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (author != null && author.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            'Compiled by $author',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
