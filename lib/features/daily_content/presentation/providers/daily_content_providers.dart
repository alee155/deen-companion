import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../data/daily_content_remote_source.dart';
import '../../data/daily_content_store.dart';
import '../../data/daily_notification_scheduler.dart';
import '../../data/repositories/daily_content_repository_impl.dart';
import '../../domain/daily_content_selector.dart';
import '../../domain/daily_notification_config.dart';
import '../../domain/entities/daily_content.dart';
import '../../domain/notification_text.dart';
import '../../domain/repositories/daily_content_repository.dart';

/// Override in tests / future remote config to change timing.
final dailyNotificationConfigProvider = Provider<DailyNotificationConfig>(
  (ref) => DailyNotificationConfig.production,
);

final dailyContentStoreProvider = Provider<DailyContentStore>(
  (ref) => DailyContentStore(ref.watch(localStorageServiceProvider)),
);

final dailyContentRepositoryProvider = Provider<DailyContentRepository>(
  (ref) => DailyContentRepositoryImpl(
    remote: DailyContentRemoteSource(ref.watch(dioProvider)),
    store: ref.watch(dailyContentStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final dailyNotificationSchedulerProvider = Provider<DailyNotificationScheduler>(
  (ref) => DailyNotificationScheduler(),
);

/// Content for a day: cached if seen before, fetched once otherwise.
final dailyContentProvider = FutureProvider.autoDispose
    .family<DailyContent, String>((ref, dateKey) async {
      final result = await ref
          .watch(dailyContentRepositoryProvider)
          .fetch(dateKey);
      return result.when(
        success: (content) => content,
        failure: (failure) => throw failure,
      );
    });

/// Master switch, persisted. On by default — the feature's point is to
/// arrive without the user doing anything.
class DailyNotificationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .read(localStorageServiceProvider)
          .get<bool>(
            AppConstants.settingsBoxName,
            AppConstants.dailyNotificationEnabledKey,
          ) ??
      true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(localStorageServiceProvider)
        .put(
          AppConstants.settingsBoxName,
          AppConstants.dailyNotificationEnabledKey,
          enabled,
        );
  }
}

final dailyNotificationEnabledProvider =
    NotifierProvider<DailyNotificationEnabledNotifier, bool>(
      DailyNotificationEnabledNotifier.new,
    );

// ── History ──────────────────────────────────────────────────────────────

class DailyNotificationRecord {
  final String id;
  final String dateKey;
  final DateTime receivedAt;
  final String title;
  final String preview;
  final bool read;
  final bool debug;

  const DailyNotificationRecord({
    required this.id,
    required this.dateKey,
    required this.receivedAt,
    required this.title,
    required this.preview,
    required this.read,
    required this.debug,
  });
}

/// Delivered notifications, newest first — built from the delivery log the
/// native receiver writes at the moment the OS posts each notification, so
/// the list is exactly what reached the tray. Refreshed by
/// `DailyNotificationService.refreshHistory` (live delivery event, resume,
/// tap, screen open, pull-to-refresh).
class NotificationHistoryNotifier
    extends Notifier<List<DailyNotificationRecord>> {
  @override
  List<DailyNotificationRecord> build() {
    final store = ref.read(dailyContentStoreProvider);
    final repository = ref.read(dailyContentRepositoryProvider);
    final title = ref.read(dailyNotificationConfigProvider).title;
    final read = store.readIds();

    return store.readDelivered().map((d) {
      return DailyNotificationRecord(
        id: d.id,
        dateKey: d.dateKey,
        receivedAt: d.deliveredAt,
        title: title,
        preview: DailyNotificationText.preview(repository.getCached(d.dateKey)),
        read: read.contains(d.id),
        debug: d.debug,
      );
    }).toList()..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  }

  Future<void> markRead(String id) async {
    final store = ref.read(dailyContentStoreProvider);
    final ids = store.readIds();
    if (!ids.add(id)) return;
    await store.writeReadIds(ids);
    ref.invalidateSelf();
  }

  Future<void> markAllRead() async {
    final store = ref.read(dailyContentStoreProvider);
    final ids = store.readIds()..addAll(state.map((r) => r.id));
    await store.writeReadIds(ids);
    ref.invalidateSelf();
  }

  void refresh() => ref.invalidateSelf();
}

final notificationHistoryProvider =
    NotifierProvider<
      NotificationHistoryNotifier,
      List<DailyNotificationRecord>
    >(NotificationHistoryNotifier.new);

final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationHistoryProvider).where((r) => !r.read).length,
);

/// Resolves which day's content a notification id opens: the stored slot's
/// day, else the id itself if it's a date, else today.
String dateKeyForNotificationId(DailyContentStore store, String id) {
  final slot = store.slotById(id);
  if (slot != null) return slot.dateKey;
  if (DailyContentSelector.parseDateKey(id) != null) return id;
  return DailyContentSelector.dateKey(DateTime.now());
}
