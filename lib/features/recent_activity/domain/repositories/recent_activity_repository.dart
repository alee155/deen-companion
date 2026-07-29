import '../entities/recent_activity_item.dart';

abstract class RecentActivityRepository {
  /// Most-recent-first, capped at [maxEntries].
  List<RecentActivityItem> getAll();

  Stream<void> watchChanges();

  /// Records that [item] was just viewed/played/opened. If an entry with
  /// the same id already exists it's moved to the top instead of
  /// duplicated. The list is then truncated to the 5 most recent entries.
  Future<void> logActivity(RecentActivityItem item);

  Future<void> clear();

  static const int maxEntries = 5;
}
