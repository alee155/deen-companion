import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../../../shared/widgets/translation_unavailable.dart';
import '../providers/verse_urdu_provider.dart';

/// The translation under a verse's Arabic, in the language the reader chose.
///
/// For screens that arrive with the English already in hand (Mutashabihat,
/// search): with English chosen it is exactly the text it always was; with
/// Urdu chosen it looks the verse's Urdu up by key and shows that instead.
/// While that loads it shows a quiet placeholder, and if the verse has no Urdu
/// it says so, or, when the Urdu just couldn't be loaded (offline), offers a
/// retry. It never substitutes the English.
class VerseTranslationText extends ConsumerWidget {
  final String verseKey;
  final String english;
  final TextStyle englishStyle;
  final bool selectable;
  final int? maxLines;

  const VerseTranslationText({
    super.key,
    required this.verseKey,
    required this.english,
    required this.englishStyle,
    this.selectable = false,
    this.maxLines,
  });

  /// Nastaliq at the size of the surrounding text: a little larger, since the
  /// script is drawn smaller than Latin at the same point size, and with the
  /// tall leading it needs.
  static TextStyle urduStyleFor(TextStyle base) => TextStyle(
    fontFamily: 'NotoNastaliqUrdu',
    fontSize: (base.fontSize ?? 14.sp) * 1.2,
    height: 2.0,
    color: base.color,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUrdu = ref.watch(
      readingPreferencesProvider.select((p) => p.isUrdu),
    );
    if (!isUrdu) return _text(english, englishStyle, urdu: false);

    final urdu = ref.watch(quranVerseUrduProvider(verseKey));
    return urdu.when(
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 16.w,
            height: 16.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
      // Couldn't be fetched (e.g. offline): say so, and let them retry.
      error: (_, _) => _unavailable(
        fontSize: englishStyle.fontSize,
        onRetry: () => ref.invalidate(quranVerseUrduProvider(verseKey)),
      ),
      data: (text) => text.trim().isEmpty
          ? _unavailable(fontSize: englishStyle.fontSize)
          : _text(text.trim(), urduStyleFor(englishStyle), urdu: true),
    );
  }

  Widget _unavailable({double? fontSize, VoidCallback? onRetry}) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TranslationUnavailable(fontSize: fontSize, onRetry: onRetry),
  );

  Widget _text(String text, TextStyle style, {required bool urdu}) {
    final align = urdu ? TextAlign.right : null;
    final direction = urdu ? TextDirection.rtl : null;
    return selectable
        ? SelectableText(
            text,
            style: style,
            textAlign: align,
            textDirection: direction,
            maxLines: maxLines,
          )
        : Text(
            text,
            style: style,
            textAlign: align,
            textDirection: direction,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          );
  }
}
