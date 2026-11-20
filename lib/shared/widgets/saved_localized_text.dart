import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/urdu_lookup.dart';
import 'translation_unavailable.dart';

/// A line of a saved row (Favorites, Recent) in the reader's language.
///
/// Those rows keep an English snapshot. With English chosen this is exactly
/// that. With Urdu chosen it is the Urdu from [lookup], nothing while that is
/// read, or (for a translation, not a title) a message that there is none:
/// never the saved English.
class SavedLocalizedText extends ConsumerWidget {
  /// The saved text (English).
  final String text;
  final TextStyle style;
  final int maxLines;

  /// Where the Urdu comes from, or null for a row this doesn't apply to.
  final ProviderListenable<UrduLookup>? lookup;

  /// A title keeps the saved text if there is no Urdu for it; a translation
  /// says so instead.
  final bool isTitle;

  /// Line height for the Urdu face, which needs more than Latin text.
  final double urduHeight;

  const SavedLocalizedText({
    super.key,
    required this.text,
    required this.style,
    required this.lookup,
    this.maxLines = 1,
    this.isTitle = false,
    this.urduHeight = 2.0,
  });

  Widget _plain() => Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: style,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = lookup == null ? UrduLookup.notUrdu : ref.watch(lookup!);
    switch (l.state) {
      case UrduState.notUrdu:
        return _plain();
      case UrduState.loading:
        return SizedBox(height: isTitle ? (style.fontSize ?? 14) * 1.4 : null);
      case UrduState.missing:
        return isTitle
            ? _plain()
            : Align(
                alignment: AlignmentDirectional.centerStart,
                child: TranslationUnavailable(fontSize: style.fontSize),
              );
      case UrduState.found:
        return SizedBox(
          width: double.infinity,
          child: Text(
            l.text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: style.copyWith(
              fontFamily: 'NotoNastaliqUrdu',
              height: urduHeight,
              letterSpacing: 0,
            ),
          ),
        );
    }
  }
}
