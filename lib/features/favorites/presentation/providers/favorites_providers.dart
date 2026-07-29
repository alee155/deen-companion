import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/datasources/favorites_local_datasource.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../domain/entities/favorite_item.dart';
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
