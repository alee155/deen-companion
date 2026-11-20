import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../../../shared/widgets/translation_unavailable.dart';
import '../providers/hadith_urdu_providers.dart';

/// The collection key out of a hadith id (`bukhari-1` → `bukhari`), or null if
/// [id] isn't one.
String? hadithCollectionOfId(String id) {
  final dash = id.indexOf('-');
  if (dash <= 0 || dash == id.length - 1) return null;
  return id.substring(0, dash);
}

/// A short preview of a hadith's translation, in the reader's language.
///
/// For places that keep a saved English snippet (Favorites, Recent). With
/// English chosen it is exactly that snippet. With Urdu chosen it is the
/// hadith's Urdu (looked up), nothing while that loads, or a message that there
/// is no Urdu — never the saved English.
class HadithPreviewText extends ConsumerWidget {
  /// The saved snippet (English).
  final String text;

  /// The hadith's id, or null when this row isn't a single hadith.
  final String? hadithId;
  final TextStyle? style;
  final int maxLines;

  const HadithPreviewText({
    super.key,
    required this.text,
    required this.hadithId,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = hadithId;
    final collection = id == null ? null : hadithCollectionOfId(id);
    final wantsUrdu =
        collection != null &&
        ref.watch(readingPreferencesProvider.select((p) => p.isUrdu));

    if (!wantsUrdu) return _plain(text);

    // A collection with no Urdu edition can't ever have one.
    if (!ApiEndpoints.hadithUrduCollections.contains(collection)) {
      return _unavailable();
    }

    final urdu = ref.watch(
      hadithUrduProvider((collection: collection, id: id!)),
    );
    if (urdu.isLoading) return const SizedBox.shrink();
    if (urdu.hasError) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TranslationUnavailable(
          fontSize: style?.fontSize ?? 12,
          onRetry: () => ref.invalidate(
            hadithUrduProvider((collection: collection, id: id)),
          ),
        ),
      );
    }
    final urduText = urdu.valueOrNull?.trim() ?? '';
    if (urduText.isEmpty) return _unavailable();

    return Text(
      urduText,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: (style ?? const TextStyle()).copyWith(
        fontFamily: 'NotoNastaliqUrdu',
        fontSize: (style?.fontSize ?? 12) * 1.15,
        height: 1.9,
      ),
    );
  }

  Widget _unavailable() => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TranslationUnavailable(fontSize: style?.fontSize ?? 12),
  );

  Widget _plain(String value) => Text(
    value,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}
