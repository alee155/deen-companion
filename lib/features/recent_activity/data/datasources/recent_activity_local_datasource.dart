import 'dart:convert';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../domain/repositories/recent_activity_repository.dart';
import '../models/recent_activity_item_model.dart';

abstract class RecentActivityLocalDataSource {
  List<RecentActivityItemModel> getAll();
  Stream<void> watchChanges();
  Future<void> logActivity(RecentActivityItemModel item);
  Future<void> clear();
}

class RecentActivityLocalDataSourceImpl
    implements RecentActivityLocalDataSource {
  final LocalStorageService storage;

  const RecentActivityLocalDataSourceImpl(this.storage);

  static const _listKey = 'recent_activity_list';

  @override
  List<RecentActivityItemModel> getAll() {
    final raw = storage.get<String>(
      AppConstants.recentActivityBoxName,
      _listKey,
    );
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => RecentActivityItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Stream<void> watchChanges() =>
      storage.watch(AppConstants.recentActivityBoxName);

  @override
  Future<void> logActivity(RecentActivityItemModel item) async {
    final current = getAll();
    // Re-viewing something already in the list moves it to the top
    // instead of creating a duplicate entry.
    current.removeWhere((e) => e.id == item.id);
    current.insert(0, item);
    final capped = current.take(RecentActivityRepository.maxEntries).toList();

    await storage.put(
      AppConstants.recentActivityBoxName,
      _listKey,
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<void> clear() {
    return storage.delete(AppConstants.recentActivityBoxName, _listKey);
  }
}
