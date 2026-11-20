import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../../../shared/widgets/translation_unavailable.dart';
import '../../domain/dua_urdu_texts.dart';
import '../providers/dua_urdu_providers.dart';
import 'dua_common.dart';

/// The title of a saved dua (Favorites, Recent), in the reader's language.
///
/// Those rows keep an English snapshot. With English chosen this is exactly
/// that; with Urdu chosen it is the dua's Urdu title, looked up by [duaId].
class SavedDuaTitle extends ConsumerWidget {
  final String duaId;

  /// The saved title (English).
  final String text;
  final TextStyle style;

  const SavedDuaTitle({
    super.key,
    required this.duaId,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(duaId);
    final wantsUrdu =
        id != null &&
        ref.watch(readingPreferencesProvider.select((p) => p.isUrdu));
    if (!wantsUrdu) return _plain();

    final texts = ref.watch(duaUrduTextsProvider);
    // Hold the space while the (bundled) Urdu is read, never flash the English.
    if (texts.isLoading) return SizedBox(height: (style.fontSize ?? 14) * 1.4);
    final title = (texts.valueOrNull ?? DuaUrduTexts.empty).titleOf(id);
    if (title == null) return _plain();
    return SizedBox(
      width: double.infinity,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: urduDuaStyle(style, height: 1.9),
      ),
    );
  }

  Widget _plain() =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
}

/// The translation snippet of a saved dua, in the reader's language: the saved
/// English, or with Urdu chosen the Urdu, or a message that there is none.
class SavedDuaPreview extends ConsumerWidget {
  final String duaId;

  /// The saved snippet (English).
  final String text;
  final TextStyle style;
  final int maxLines;

  const SavedDuaPreview({
    super.key,
    required this.duaId,
    required this.text,
    required this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(duaId);
    final wantsUrdu =
        id != null &&
        ref.watch(readingPreferencesProvider.select((p) => p.isUrdu));
    if (!wantsUrdu) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final texts = ref.watch(duaUrduTextsProvider);
    if (texts.isLoading) return const SizedBox.shrink();
    final urdu = (texts.valueOrNull ?? DuaUrduTexts.empty).translationOf(id);
    if (urdu == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TranslationUnavailable(fontSize: style.fontSize),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Text(
        urdu,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: urduDuaStyle(style, height: 2.0),
      ),
    );
  }
}
