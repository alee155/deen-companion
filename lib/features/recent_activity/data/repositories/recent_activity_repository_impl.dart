import '../../domain/entities/recent_activity_item.dart';
import '../../domain/repositories/recent_activity_repository.dart';
import '../datasources/recent_activity_local_datasource.dart';
import '../models/recent_activity_item_model.dart';

class RecentActivityRepositoryImpl implements RecentActivityRepository {
  final RecentActivityLocalDataSource localDataSource;

  const RecentActivityRepositoryImpl(this.localDataSource);

  @override
  List<RecentActivityItem> getAll() {
    return localDataSource.getAll().map((m) => m.toEntity()).toList();
  }

  @override
  Stream<void> watchChanges() => localDataSource.watchChanges();

  @override
  Future<void> logActivity(RecentActivityItem item) {
    return localDataSource.logActivity(
      RecentActivityItemModel.fromEntity(item),
    );
  }

  @override
  Future<void> clear() => localDataSource.clear();
}
