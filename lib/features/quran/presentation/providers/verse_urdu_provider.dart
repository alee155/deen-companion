import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/di/providers.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../data/datasources/quran_verse_urdu_datasource.dart';

final quranVerseUrduDataSourceProvider = Provider<QuranVerseUrduDataSource>(
  (ref) => QuranVerseUrduDataSource(ref.watch(dioProvider)),
);

/// `'2:255'` → (2, 255), or null if it isn't a verse key.
(int, int)? parseVerseKey(String verseKey) {
  final parts = verseKey.split(':');
  if (parts.length != 2) return null;
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  if (surah == null || ayah == null) return null;
  return (surah, ayah);
}

/// Thrown when a verse's Urdu couldn't be fetched (offline, error), as opposed
/// to the source having none.
class VerseUrduLoadFailure implements Exception {
  const VerseUrduLoadFailure();
  @override
  String toString() => 'Could not load the Urdu translation';
}

/// The Urdu translation of one verse, by key (`'2:255'`), or `''` when there
/// is none. Fails with [VerseUrduLoadFailure] when it couldn't be loaded.
///
/// Saved on the device once fetched, so a verse seen once reads offline. A
/// failed request is not saved and simply tries again next time. Fetched only
/// when asked for, so a long list loads Urdu for the rows actually on screen.
final quranVerseUrduProvider = FutureProvider.autoDispose
    .family<String, String>((ref, verseKey) async {
      final parsed = parseVerseKey(verseKey);
      if (parsed == null) return '';

      final cache = ref.read(hiveCacheStoreProvider);
      final key = 'quran_urdu_${parsed.$1}_${parsed.$2}';
      final saved = cache.read<String>(key, (json) => json['text'] as String);
      if (saved != null) return saved.data;

      final text = await ref
          .read(quranVerseUrduDataSourceProvider)
          .fetch(parsed.$1, parsed.$2);
      if (text == null) throw const VerseUrduLoadFailure();

      await cache.save<String>(key, text, (value) => {'text': value});
      return text;
    });

/// The translation to hand to Copy / Share for a verse: its Urdu when the
/// reader has chosen Urdu, or an empty string when they have but there is none
/// (or it hasn't loaded) — never the English they didn't ask for. With English
/// chosen, [english].
String shownVerseTranslation(WidgetRef ref, String verseKey, String english) {
  if (!ref.read(readingPreferencesProvider).isUrdu) return english;
  return ref.read(quranVerseUrduProvider(verseKey)).valueOrNull?.trim() ?? '';
}
