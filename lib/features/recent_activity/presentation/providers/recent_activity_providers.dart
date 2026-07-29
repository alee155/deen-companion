import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/datasources/recent_activity_local_datasource.dart';
import '../../data/repositories/recent_activity_repository_impl.dart';
import '../../domain/entities/recent_activity_item.dart';
import '../../domain/repositories/recent_activity_repository.dart';

final recentActivityLocalDataSourceProvider =
    Provider<RecentActivityLocalDataSource>((ref) {
      return RecentActivityLocalDataSourceImpl(
        ref.watch(localStorageServiceProvider),
      );
    });

final recentActivityRepositoryProvider = Provider<RecentActivityRepository>((
  ref,
) {
  return RecentActivityRepositoryImpl(
    ref.watch(recentActivityLocalDataSourceProvider),
  );
});

/// The 5 most recent activities, most-recent-first, kept live.
class RecentActivityNotifier extends StreamNotifier<List<RecentActivityItem>> {
  @override
  Stream<List<RecentActivityItem>> build() async* {
    final repository = ref.watch(recentActivityRepositoryProvider);
    yield repository.getAll();
    yield* repository.watchChanges().map((_) => repository.getAll());
  }

  Future<void> logActivity(RecentActivityItem item) {
    return ref.read(recentActivityRepositoryProvider).logActivity(item);
  }

  Future<void> clear() => ref.read(recentActivityRepositoryProvider).clear();
}

final recentActivityNotifierProvider =
    StreamNotifierProvider<RecentActivityNotifier, List<RecentActivityItem>>(
      RecentActivityNotifier.new,
    );
