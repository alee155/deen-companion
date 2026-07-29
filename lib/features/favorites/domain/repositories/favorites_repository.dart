import '../entities/favorite_item.dart';

abstract class FavoritesRepository {
  /// Synchronous read of everything currently favorited.
  List<FavoriteItem> getAll();

  bool isFavorite(String id);

  /// Emits whenever the underlying storage changes, so the UI can stay in
  /// sync without every caller remembering to invalidate a provider.
  Stream<void> watchChanges();

  Future<void> add(FavoriteItem item);
  Future<void> remove(String id);

  /// Adds the item if it isn't already favorited, removes it otherwise.
  /// Returns the resulting favorited state (true = now favorited).
  Future<bool> toggle(FavoriteItem item);
}
