import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../domain/dua_urdu_texts.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/duas_bundle.dart';
import 'dua_providers.dart';

/// Where the bundled Urdu lives.
const duaUrduAsset = 'assets/data/duas_urdu.json';

/// The Urdu for the duas, read from the app's own files.
final duaUrduTextsProvider = FutureProvider<DuaUrduTexts>((ref) async {
  return DuaUrduTexts.parse(await rootBundle.loadString(duaUrduAsset));
});

bool _wantsUrdu(Ref ref) =>
    ref.watch(readingPreferencesProvider.select((p) => p.isUrdu));

/// The duas bundle in the reader's language.
///
/// English is the bundle as the source gave it. With Urdu chosen every title,
/// translation and category name is the Urdu; a dua with no Urdu translation
/// has none, and the screen says so rather than showing the English.
final localizedDuasBundleProvider = Provider<AsyncValue<DuasBundle>>((ref) {
  final bundle = ref.watch(duasBundleNotifierProvider);
  if (!_wantsUrdu(ref)) return bundle;
  final texts = ref.watch(duaUrduTextsProvider);
  return bundle.when(
    data: (b) => texts.when(
      data: (t) => AsyncData(t.bundle(b)),
      loading: () => const AsyncLoading<DuasBundle>(),
      // The bundled file can't be read: say "not available", don't show English.
      error: (_, _) => AsyncData(DuaUrduTexts.empty.bundle(b)),
    ),
    loading: () => const AsyncLoading<DuasBundle>(),
    error: (e, s) => AsyncError<DuasBundle>(e, s),
  );
});

/// Search results in the reader's language.
final localizedDuaSearchProvider = Provider<AsyncValue<List<Dua>?>>((ref) {
  final results = ref.watch(duaSearchNotifierProvider);
  if (!_wantsUrdu(ref)) return results;
  final texts = ref.watch(duaUrduTextsProvider);
  return results.when(
    data: (list) => list == null
        ? const AsyncData<List<Dua>?>(null)
        : texts.when(
            data: (t) => AsyncData([for (final d in list) t.dua(d)]),
            loading: () => const AsyncLoading<List<Dua>?>(),
            error: (_, _) =>
                AsyncData([for (final d in list) DuaUrduTexts.empty.dua(d)]),
          ),
    loading: () => const AsyncLoading<List<Dua>?>(),
    error: (e, s) => AsyncError<List<Dua>?>(e, s),
  );
});
