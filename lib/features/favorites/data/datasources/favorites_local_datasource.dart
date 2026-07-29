import 'dart:convert';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/favorite_item_model.dart';

abstract class FavoritesLocalDataSource {
  List<FavoriteItemModel> getAll();
  bool isFavorite(String id);
  Stream<void> watchChanges();
  Future<void> add(FavoriteItemModel item);
  Future<void> remove(String id);
}

class FavoritesLocalDataSourceImpl implements FavoritesLocalDataSource {
  final LocalStorageService storage;

  const FavoritesLocalDataSourceImpl(this.storage);

  @override
  List<FavoriteItemModel> getAll() {
    final raw = storage.getAll(AppConstants.bookmarksBoxName);
    return raw.values
        .map(
          (v) => FavoriteItemModel.fromJson(
            jsonDecode(v as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  bool isFavorite(String id) =>
      storage.get<String>(AppConstants.bookmarksBoxName, id) != null;

  @override
  Stream<void> watchChanges() => storage.watch(AppConstants.bookmarksBoxName);

  @override
  Future<void> add(FavoriteItemModel item) {
    return storage.put(
      AppConstants.bookmarksBoxName,
      item.id,
      jsonEncode(item.toJson()),
    );
  }

  @override
  Future<void> remove(String id) {
    return storage.delete(AppConstants.bookmarksBoxName, id);
  }
}
