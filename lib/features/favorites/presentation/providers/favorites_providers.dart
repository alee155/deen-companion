import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/datasources/favorites_local_datasource.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../domain/entities/favorite_item.dart';
import '../../domain/favorites_filter.dart';
import '../../domain/repositories/favorites_repository.dart';

final favoritesLocalDataSourceProvider = Provider<FavoritesLocalDataSource>((
  ref,
) {
  return FavoritesLocalDataSourceImpl(ref.watch(localStorageServiceProvider));
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepositoryImpl(ref.watch(favoritesLocalDataSourceProvider));
});

/// The full favorites list, kept live: reads from storage immediately, then
/// re-reads every time storage changes (toggling a favorite from anywhere
/// in the app updates every screen watching this provider).
class FavoritesNotifier extends StreamNotifier<List<FavoriteItem>> {
  @override
  Stream<List<FavoriteItem>> build() async* {
    final repository = ref.watch(favoritesRepositoryProvider);
    yield repository.getAll();
    yield* repository.watchChanges().map((_) => repository.getAll());
  }

  Future<void> toggle(FavoriteItem item) =>
      ref.read(favoritesRepositoryProvider).toggle(item);

  Future<void> remove(String id) =>
      ref.read(favoritesRepositoryProvider).remove(id);
}

final favoritesNotifierProvider =
    StreamNotifierProvider<FavoritesNotifier, List<FavoriteItem>>(
      FavoritesNotifier.new,
    );

/// Whether a specific item is currently favorited. Widgets like a heart
/// toggle button should watch this (via `.select`-like family scoping)
/// rather than the whole list, so adding a favorite to Hadith doesn't
/// rebuild every Surah tile on screen.
final isFavoriteProvider = Provider.family<bool, String>((ref, id) {
  final favorites = ref.watch(favoritesNotifierProvider).valueOrNull ?? [];
  return favorites.any((f) => f.id == id);
});

/// What the user typed in the Favorites search box. Reset when they leave.
final favoritesQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// The category chip the user picked (null = All).
final _pickedTypeProvider = StateProvider.autoDispose<FavoriteContentType?>(
  (ref) => null,
);

final favoriteTypeCountsProvider =
    Provider.autoDispose<Map<FavoriteContentType, int>>((ref) {
      final all = ref.watch(favoritesNotifierProvider).valueOrNull ?? const [];
      return countFavoritesByType(all);
    });

/// The category filter in force. Falls back to All when the picked category
/// has no favorites left (e.g. the last one was just removed), so the screen
/// never sits on an empty filter the user can no longer see a chip for.
final favoritesTypeFilterProvider = Provider.autoDispose<FavoriteContentType?>((
  ref,
) {
  final picked = ref.watch(_pickedTypeProvider);
  final counts = ref.watch(favoriteTypeCountsProvider);
  return picked != null && counts.containsKey(picked) ? picked : null;
});

void pickFavoritesType(WidgetRef ref, FavoriteContentType? type) =>
    ref.read(_pickedTypeProvider.notifier).state = type;

/// The favorites to show, after the category and search filters.
final visibleFavoritesProvider = Provider.autoDispose<List<FavoriteItem>>((
  ref,
) {
  final all = ref.watch(favoritesNotifierProvider).valueOrNull ?? const [];
  return filterFavorites(
    all,
    type: ref.watch(favoritesTypeFilterProvider),
    query: ref.watch(favoritesQueryProvider),
  );
});
