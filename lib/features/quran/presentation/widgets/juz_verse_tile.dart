import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/share_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../../../shared/widgets/translation_unavailable.dart';
import '../../domain/entities/juz.dart';

/// The verse's translation in [language]. In Urdu this is the Urdu text or,
/// when the verse has none, an empty string — never the English, which the
/// reader didn't ask for. (The tile says the Urdu is unavailable.)
String resolveTranslation(
  JuzVerse verse, [
  TranslationLanguage language = TranslationLanguage.english,
]) {
  if (language == TranslationLanguage.urdu) {
    return verse.translations['urdu']?.trim() ?? '';
  }
  return verse.translations['sahih_international'] ??
      (verse.translations.values.isEmpty
          ? ''
          : verse.translations.values.first);
}

/// A short-form share/copy text for a single verse — Arabic, translation,
/// and a reference line, in that order.
String _shareTextFor(JuzVerse verse, String translation) {
  return [
    verse.arabic.trim(),
    if (translation.trim().isNotEmpty) translation.trim(),
    '— ${verse.surahName}, Ayah ${verse.ayah}',
  ].join('\n\n');
}

/// One verse: Arabic set from the right in the brand's orange, the
/// translation set from the left in ink (black in Light, white in Dark).
class JuzVerseTile extends StatelessWidget {
  final JuzVerse verse;
  final ReadingPreferences preferences;

  /// Shows a small "surah begins" banner above the verse — used when a new
  /// surah starts partway down a page (a page's own running header already
  /// announces the surah its first verse belongs to).
  final bool showSurahBanner;

  const JuzVerseTile({
    super.key,
    required this.verse,
    required this.preferences,
    this.showSurahBanner = false,
  });

  String get _translation =>
      resolveTranslation(verse, preferences.translationLanguage);

  /// True when the text shown is Urdu (right-to-left, Nastaliq).
  bool get _showingUrdu => preferences.isUrdu && _translation.isNotEmpty;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: _shareTextFor(verse, _translation)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verse copied, with its reference')),
    );
  }

  Future<void> _share(BuildContext context) => shareText(
    context,
    _shareTextFor(verse, _translation),
    subject: verse.surahName,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSurahBanner) ...[
          _SurahBanner(name: verse.surahName),
          SizedBox(height: 10.h),
        ],
        Row(
          children: [
            SealNumberBadge(number: verse.ayah, size: 34.w),
            const Spacer(),
            PopupMenuButton<VoidCallback>(
              tooltip: 'More',
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                size: 17.sp,
                color: AppColors.textMuted,
              ),
              color: AppColors.surfaceLight,
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: () => _copy(context),
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
                  value: () => _share(context),
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
        if (preferences.showArabic) ...[
          SizedBox(height: 6.h),
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
            child: Semantics(
              label: 'Arabic text of the verse',
              child: SelectableText(
                verse.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: preferences.arabicStyle.copyWith(
                  color: AppColors.emeraldInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        // Urdu chosen but this verse has none: say so, don't show English.
        if (preferences.showTranslation &&
            preferences.isUrdu &&
            _translation.isEmpty) ...[
          SizedBox(height: 8.h),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: TranslationUnavailable(),
          ),
        ],
        if (preferences.showTranslation && _translation.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Semantics(
            label: _showingUrdu
                ? 'Urdu translation of the verse'
                : 'English translation of the verse',
            child: SelectableText(
              _translation,
              textAlign: _showingUrdu ? TextAlign.right : TextAlign.left,
              textDirection: _showingUrdu
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style:
                  (_showingUrdu
                          ? preferences.urduStyle
                          : preferences.englishStyle)
                      .copyWith(color: AppColors.inkText),
            ),
          ),
        ],
      ],
    );
  }
}

/// Marks where a new surah begins partway down a page.
class _SurahBanner extends StatelessWidget {
  final String name;
  const _SurahBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.quranAccentBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 13.sp,
            color: AppColors.quranAccent,
          ),
          SizedBox(width: 6.w),
          Text(
            name,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.quranAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
