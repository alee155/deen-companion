import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/domain/urdu_lookup.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../domain/islamic_names_urdu_texts.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/islamic_names_remote_datasource.dart';
import '../../data/repositories/islamic_names_repository_impl.dart';
import '../../domain/entities/islamic_name.dart';
import '../../domain/repositories/islamic_names_repository.dart';
import '../../../../core/usecase/usecase.dart';

final islamicNamesRemoteDataSourceProvider =
    Provider<IslamicNamesRemoteDataSource>((ref) {
      return IslamicNamesRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final islamicNamesRepositoryProvider = Provider<IslamicNamesRepository>((ref) {
  return IslamicNamesRepositoryImpl(
    remoteDataSource: ref.watch(islamicNamesRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class IslamicNamesNotifier extends CacheFirstStreamNotifier<List<IslamicName>> {
  @override
  List<IslamicName>? readCache() =>
      ref.read(islamicNamesRepositoryProvider).getCachedNames();

  @override
  Future<Result<List<IslamicName>>> fetchFresh() =>
      ref.read(islamicNamesRepositoryProvider).fetchAndCacheNames();
}

final islamicNamesNotifierProvider =
    StreamNotifierProvider<IslamicNamesNotifier, List<IslamicName>>(
      IslamicNamesNotifier.new,
    );

/// Where the bundled Urdu lives.
const islamicNamesUrduAsset = 'assets/data/islamic_names_urdu.json';

/// The Urdu for the names, read from the app's own files.
final islamicNamesUrduTextsProvider = FutureProvider<IslamicNamesUrduTexts>((
  ref,
) async {
  return IslamicNamesUrduTexts.parse(
    await rootBundle.loadString(islamicNamesUrduAsset),
  );
});

bool _wantsUrdu(Ref ref) =>
    ref.watch(readingPreferencesProvider.select((p) => p.isUrdu));

/// The names in the reader's language. English is the list as the source gave
/// it. With Urdu chosen every name, meaning, origin and note is the Urdu; one
/// with no Urdu has none, and the screen says so rather than showing English.
final localizedIslamicNamesProvider = Provider<AsyncValue<List<IslamicName>>>((
  ref,
) {
  final names = ref.watch(islamicNamesNotifierProvider);
  if (!_wantsUrdu(ref)) return names;
  final texts = ref.watch(islamicNamesUrduTextsProvider);
  return names.when(
    data: (list) => texts.when(
      data: (t) => AsyncData(t.names(list)),
      loading: () => const AsyncLoading<List<IslamicName>>(),
      error: (_, _) => AsyncData(IslamicNamesUrduTexts.empty.names(list)),
    ),
    loading: () => const AsyncLoading<List<IslamicName>>(),
    error: (e, s) => AsyncError<List<IslamicName>>(e, s),
  );
});

/// A saved name's Urdu name (Favorites, Recent), from its id.
final savedIslamicNameNameProvider = Provider.family<UrduLookup, String>(
  (ref, id) => _savedLookup(ref, id, (t, n) => t.nameOf(n)),
);

/// A saved name's Urdu meaning (Favorites, Recent), from its id.
final savedIslamicNameMeaningProvider = Provider.family<UrduLookup, String>(
  (ref, id) => _savedLookup(ref, id, (t, n) => t.meaningOf(n)),
);

UrduLookup _savedLookup(
  Ref ref,
  String id,
  String? Function(IslamicNamesUrduTexts texts, int id) pick,
) {
  final number = int.tryParse(id);
  if (number == null || !_wantsUrdu(ref)) return UrduLookup.notUrdu;
  final texts = ref.watch(islamicNamesUrduTextsProvider);
  if (texts.isLoading) return UrduLookup.loading;
  return UrduLookup.of(
    pick(texts.valueOrNull ?? IslamicNamesUrduTexts.empty, number),
  );
}
