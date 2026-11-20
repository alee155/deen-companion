import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/urdu_lookup.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../domain/asma_urdu_texts.dart';
import '../../domain/entities/asma_daily.dart';
import '../../domain/entities/asma_name.dart';
import 'asma_ul_husna_providers.dart';

const asmaUrduAsset = 'assets/data/asma_urdu.json';

/// The Urdu for the Names, read from the app's own files.
final asmaUrduTextsProvider = FutureProvider<AsmaUrduTexts>((ref) async {
  return AsmaUrduTexts.parse(await rootBundle.loadString(asmaUrduAsset));
});

bool _wantsUrdu(Ref ref) =>
    ref.watch(readingPreferencesProvider.select((p) => p.isUrdu));

/// Runs [convert] on a result with the Urdu once it is read. English passes
/// straight through; if the bundled file can't be read, the Names have no Urdu
/// and say so, rather than showing English.
AsyncValue<T> _localized<T>(
  Ref ref,
  AsyncValue<T> source,
  T Function(AsmaUrduTexts texts, T value) convert,
) {
  if (!_wantsUrdu(ref)) return source;
  final texts = ref.watch(asmaUrduTextsProvider);
  return source.when(
    data: (v) => texts.when(
      data: (t) => AsyncData(convert(t, v)),
      loading: () => AsyncLoading<T>(),
      error: (_, _) => AsyncData(convert(AsmaUrduTexts.empty, v)),
    ),
    loading: () => AsyncLoading<T>(),
    error: (e, s) => AsyncError<T>(e, s),
  );
}

/// All 99 Names in the reader's language.
final localizedAsmaNamesProvider = Provider<AsyncValue<List<AsmaName>>>(
  (ref) => _localized(
    ref,
    ref.watch(asmaAllNamesNotifierProvider),
    (t, v) => t.names(v),
  ),
);

/// One day's Names in the reader's language.
final localizedAsmaDailyProvider = Provider.family<AsyncValue<AsmaDaily>, int>(
  (ref, day) => _localized(
    ref,
    ref.watch(asmaDailyNotifierProvider(day)),
    (t, v) => t.daily(v),
  ),
);

/// Search results in the reader's language.
final localizedAsmaSearchProvider = Provider<AsyncValue<List<AsmaName>?>>(
  (ref) => _localized(
    ref,
    ref.watch(asmaSearchNotifierProvider),
    (t, v) => v == null ? null : t.names(v),
  ),
);

/// A saved Name's epithet (Favorites, Recent), from its number.
final savedAsmaEpithetProvider = Provider.family<UrduLookup, String>(
  (ref, id) => _savedLookup(ref, id, (t, n) => t.epithetOf(n)),
);

/// A saved Name's meaning (Favorites, Recent), from its number.
final savedAsmaMeaningProvider = Provider.family<UrduLookup, String>(
  (ref, id) => _savedLookup(ref, id, (t, n) => t.meaningOf(n)),
);

UrduLookup _savedLookup(
  Ref ref,
  String id,
  String? Function(AsmaUrduTexts texts, int number) pick,
) {
  final number = int.tryParse(id);
  if (number == null || !_wantsUrdu(ref)) return UrduLookup.notUrdu;
  final texts = ref.watch(asmaUrduTextsProvider);
  if (texts.isLoading) return UrduLookup.loading;
  return UrduLookup.of(pick(texts.valueOrNull ?? AsmaUrduTexts.empty, number));
}
