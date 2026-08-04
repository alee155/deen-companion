import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../domain/entities/juz.dart';

/// A short-form share/copy text for a single verse — Arabic, translation,
/// and a reference line, in that order.
String _shareTextFor(JuzVerse verse, String translation) {
  return [
    verse.arabic.trim(),
    translation.trim(),
    '— ${verse.surahName}, Ayah ${verse.ayah}',
  ].join('\n\n');
}

class JuzVerseTile extends StatelessWidget {
  final JuzVerse verse;
  final ReadingPreferences preferences;

  const JuzVerseTile({
    super.key,
    required this.verse,
    required this.preferences,
  });

  String get _translation =>
      verse.translations['sahih_international'] ??
      (verse.translations.values.isEmpty
          ? ''
          : verse.translations.values.first);

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: _shareTextFor(verse, _translation)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verse copied, with its reference')),
    );
  }

  Future<void> _share() =>
      Share.share(_shareTextFor(verse, _translation), subject: verse.surahName);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26.w,
                height: 26.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.quranAccentBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${verse.ayah}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.quranAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  verse.surahName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
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
                    value: _share,
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
            SizedBox(height: 10.h),
            Semantics(
              label: 'Arabic text of the verse',
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: preferences.arabicStyle.copyWith(
                  color: AppColors.inkText,
                ),
                child: SelectableText(
                  verse.arabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: preferences.arabicStyle.copyWith(
                    color: AppColors.inkText,
                  ),
                ),
              ),
            ),
          ],
          if (preferences.showTranslation && _translation.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Semantics(
              label: 'English translation of the verse',
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: preferences.englishStyle.copyWith(
                  color: AppColors.inkText,
                ),
                child: SelectableText(
                  _translation,
                  style: preferences.englishStyle.copyWith(
                    color: AppColors.inkText,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
