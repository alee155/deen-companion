import '../../domain/entities/favorite_item.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_local_datasource.dart';
import '../models/favorite_item_model.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesLocalDataSource localDataSource;

  const FavoritesRepositoryImpl(this.localDataSource);

  @override
  List<FavoriteItem> getAll() {
    final items = localDataSource.getAll().map((m) => m.toEntity()).toList();
    items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }

  @override
  bool isFavorite(String id) => localDataSource.isFavorite(id);

  @override
  Stream<void> watchChanges() => localDataSource.watchChanges();

  @override
  Future<void> add(FavoriteItem item) {
    return localDataSource.add(FavoriteItemModel.fromEntity(item));
  }

  @override
  Future<void> remove(String id) => localDataSource.remove(id);

  @override
  Future<bool> toggle(FavoriteItem item) async {
    if (localDataSource.isFavorite(item.id)) {
      await localDataSource.remove(item.id);
      return false;
    }
    await localDataSource.add(FavoriteItemModel.fromEntity(item));
    return true;
  }
}
