import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../data/datasources/hadith_urdu_datasource.dart';
import '../../domain/entities/hadith.dart';

final hadithUrduDataSourceProvider = Provider<HadithUrduDataSource>(
  (ref) => HadithUrduDataSource(),
);

/// The whole number in a hadith id (`bukhari-1` → 1), or null for the
/// sub-narrations numbered like `402.2`. Those can't be matched safely — the
/// hadith entity rounds the number — so they get English rather than the
/// translation of a neighbouring hadith.
int? _wholeNumber(HadithUrduKey key) {
  final prefix = '${key.collection}-';
  if (!key.id.startsWith(prefix)) return null;
  return int.tryParse(key.id.substring(prefix.length));
}

/// What identifies one hadith for its Urdu translation. A record, so equal
/// keys share one provider however many times the entity is rebuilt.
typedef HadithUrduKey = ({String collection, String id});

HadithUrduKey urduKeyOf(Hadith hadith) =>
    (collection: hadith.collection, id: hadith.id);

/// Whether an Urdu translation could exist for [hadith] at all, so the reader
/// doesn't wait on a request that cannot succeed.
bool hasUrduEdition(Hadith hadith) {
  final key = urduKeyOf(hadith);
  return ApiEndpoints.hadithUrduCollections.contains(key.collection) &&
      _wholeNumber(key) != null;
}

String _cacheKey(HadithUrduKey key) =>
    'hadith_urdu_${key.collection}_${_wholeNumber(key)}';

/// Thrown when the Urdu couldn't be fetched (offline, server error), as
/// opposed to the source confirming there is none. The screen shows "couldn't
/// load" with a retry instead of claiming it doesn't exist.
class HadithUrduLoadFailure implements Exception {
  const HadithUrduLoadFailure();
  @override
  String toString() => 'Could not load the Urdu translation';
}

/// The Urdu translation of one hadith, or `''` when there is none. Fails with
/// [HadithUrduLoadFailure] when it couldn't be loaded.
///
/// Read from the saved copy first, so a hadith read once is available
/// offline. A confirmed "none" is saved too (so it isn't asked for again),
/// but a failed request isn't: it tries again next time.
///
/// Not kept alive: the text is held on disk, not in memory.
final hadithUrduProvider = FutureProvider.autoDispose
    .family<String, HadithUrduKey>((ref, hadithKey) async {
      final number = _wholeNumber(hadithKey);
      if (number == null ||
          !ApiEndpoints.hadithUrduCollections.contains(hadithKey.collection)) {
        return '';
      }

      final cache = ref.read(hiveCacheStoreProvider);
      final key = _cacheKey(hadithKey);
      final saved = cache.read<String>(key, (json) => json['text'] as String);
      if (saved != null) return saved.data;

      final text = await ref
          .read(hadithUrduDataSourceProvider)
          .fetch(hadithKey.collection, number);
      if (text == null) throw const HadithUrduLoadFailure();

      await cache.save<String>(key, text, (value) => {'text': value});
      return text;
    });

/// What to hand to Copy / Share as the translation: null with English chosen
/// (the English is used as before); with Urdu chosen, the Urdu text, or an
/// empty string when there is none (or it hasn't loaded), which leaves the
/// translation out — the English is not substituted.
String? shownUrduFor(WidgetRef ref, Hadith hadith) {
  if (!ref.read(readingPreferencesProvider).isUrdu) return null;
  final text = ref.read(hadithUrduProvider(urduKeyOf(hadith))).valueOrNull;
  return text?.trim() ?? '';
}
