import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/share_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../../quran/presentation/providers/verse_urdu_provider.dart';
import '../../../quran/presentation/widgets/verse_translation_text.dart';
import '../../domain/entities/mutashabihat_verse_ref.dart';
import '../utils/arabic_diff.dart';
import 'highlighted_arabic_text.dart';

/// [translation] is what the reader is looking at (their language), so what
/// they copy is what they read.
String _shareTextFor(MutashabihatVerseRef verse, String translation) => [
  verse.arabic.trim(),
  if (translation.trim().isNotEmpty) translation.trim(),
  '— ${verse.surahNameEnglish}, Ayah ${verse.ayah}',
].join('\n\n');

/// The anchor verse a group of lookalikes is compared against — set apart
/// from the similar-verse cards below it with a tinted, bordered "hero"
/// treatment, the way [JuzVerseTile]'s surah banner marks structural chrome
/// with the module's green accent while the verse text itself stays in the
/// brand orange used everywhere Quran text is read.
class MutashabihatBaseVerseCard extends ConsumerWidget {
  final MutashabihatVerseRef verse;

  /// The Arabic of every similar verse in this group — used only to decide
  /// which of the base verse's own words are worth highlighting (see
  /// [baseDiffTokens]).
  final List<String> otherArabic;

  const MutashabihatBaseVerseCard({
    super.key,
    required this.verse,
    required this.otherArabic,
  });

  String _shown(WidgetRef ref) =>
      shownVerseTranslation(ref, verse.verseKey, verse.translation);

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    await Clipboard.setData(
      ClipboardData(text: _shareTextFor(verse, _shown(ref))),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Verse copied')));
  }

  Future<void> _share(BuildContext context, WidgetRef ref) => shareText(
    context,
    _shareTextFor(verse, _shown(ref)),
    subject: verse.surahNameEnglish,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = baseDiffTokens(verse.arabic, otherArabic);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.quranAccentBg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.quranAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_rounded,
                size: 14.sp,
                color: AppColors.quranAccent,
              ),
              SizedBox(width: 6.w),
              Text(
                'THE VERSE',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.quranAccent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              PopupMenuButton<VoidCallback>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18.sp,
                  color: AppColors.textMuted,
                ),
                color: AppColors.surfaceLight,
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: () => _copy(context, ref),
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 18.sp,
                          color: AppColors.inkText,
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'Copy verse',
                          style: TextStyle(color: AppColors.inkText),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: () => _share(context, ref),
                    child: Row(
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          size: 18.sp,
                          color: AppColors.inkText,
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'Share verse',
                          style: TextStyle(color: AppColors.inkText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsetsDirectional.only(end: 12.w),
            decoration: BoxDecoration(
              border: BorderDirectional(
                end: BorderSide(
                  color: AppColors.emeraldInk.withValues(alpha: 0.45),
                  width: 2.5,
                ),
              ),
            ),
            child: HighlightedArabicText(
              tokens: tokens,
              style: AppTypography.arabicBody.copyWith(
                fontSize: 21.sp,
                height: 1.9,
                color: AppColors.emeraldInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          VerseTranslationText(
            verseKey: verse.verseKey,
            english: verse.translation,
            selectable: true,
            englishStyle: AppTypography.bodyLarge.copyWith(
              color: AppColors.inkText,
              height: 1.6,
            ),
          ),
          SizedBox(height: 14.h),
          OrnamentDivider(ruleWidth: 24.w),
          SizedBox(height: 10.h),
          Row(
            children: [
              SealNumberBadge(number: verse.ayah, size: 30.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  '${verse.surahNameEnglish} · ${verse.verseKey}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
