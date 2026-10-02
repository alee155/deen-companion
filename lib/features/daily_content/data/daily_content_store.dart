import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../hadith/data/models/hadith_model.dart';
import '../domain/entities/daily_content.dart';

/// One notification slot — a moment the daily notification was (or will be)
/// delivered. History is derived from these: a slot whose time has passed is
/// a delivered notification. That is how entries get recorded even though
/// the notification itself fires natively with the app closed.
class NotificationSlot {
  /// What a notification tap hands back — the date key for real slots,
  /// `debug-<epoch>` for test ones.
  final String id;

  /// The day whose Ayat/Hadith this slot opens.
  final String dateKey;
  final int epochMillis;
  final bool debug;

  const NotificationSlot({
    required this.id,
    required this.dateKey,
    required this.epochMillis,
    this.debug = false,
  });

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(epochMillis);

  Map<String, dynamic> toJson() => {
    'id': id,
    'dateKey': dateKey,
    'epochMillis': epochMillis,
    'debug': debug,
  };

  factory NotificationSlot.fromJson(Map<String, dynamic> json) =>
      NotificationSlot(
        id: json['id'] as String,
        dateKey: json['dateKey'] as String,
        epochMillis: json['epochMillis'] as int,
        debug: json['debug'] as bool? ?? false,
      );
}

/// A notification the OS actually delivered — what the history shows.
class DeliveredNotification {
  final String id;
  final String dateKey;
  final int deliveredAtMillis;
  final bool debug;

  const DeliveredNotification({
    required this.id,
    required this.dateKey,
    required this.deliveredAtMillis,
    this.debug = false,
  });

  DateTime get deliveredAt =>
      DateTime.fromMillisecondsSinceEpoch(deliveredAtMillis);

  Map<String, dynamic> toJson() => {
    'id': id,
    'dateKey': dateKey,
    'deliveredAt': deliveredAtMillis,
    'debug': debug,
  };

  factory DeliveredNotification.fromJson(Map<String, dynamic> json) =>
      DeliveredNotification(
        id: json['id'] as String,
        dateKey: json['dateKey'] as String,
        deliveredAtMillis: json['deliveredAt'] as int,
        debug: json['debug'] as bool? ?? false,
      );
}

/// Persistence for the daily-content feature: cached content per day, the
/// notification slots, and which ones the user has read. Everything is
/// JSON-encoded strings in its own Hive box so a cache clear in Settings
/// (which targets the API cache box) never wipes the notification history.
class DailyContentStore {
  final LocalStorageService storage;
  const DailyContentStore(this.storage);

  static const _box = AppConstants.dailyContentBoxName;
  static const _slotsKey = 'slots';
  static const _readKey = 'read';
  static const _deliveredKey = 'delivered';
  static const _contentPrefix = 'content:';

  // ── Content cache ──────────────────────────────────────────────────────

  DailyContent? readContent(String dateKey) {
    final raw = storage.get<String>(_box, '$_contentPrefix$dateKey');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DailyContent(
        dateKey: dateKey,
        ayah: DailyAyah.fromJson(json['ayah'] as Map<String, dynamic>),
        hadith: HadithModel.fromJson(
          json['hadith'] as Map<String, dynamic>,
        ).toEntity(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeContent(
    String dateKey,
    DailyAyah ayah,
    HadithModel hadith,
  ) => storage.put(
    _box,
    '$_contentPrefix$dateKey',
    jsonEncode({'ayah': ayah.toJson(), 'hadith': hadith.toJson()}),
  );

  Future<void> pruneContentBefore(String dateKey) async {
    for (final key in storage.getAll(_box).keys) {
      if (!key.startsWith(_contentPrefix)) continue;
      if (key.substring(_contentPrefix.length).compareTo(dateKey) < 0) {
        await storage.delete(_box, key);
      }
    }
  }

  // ── Slots ──────────────────────────────────────────────────────────────

  List<NotificationSlot> readSlots() {
    final raw = storage.get<String>(_box, _slotsKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => NotificationSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeSlots(List<NotificationSlot> slots) => storage.put(
    _box,
    _slotsKey,
    jsonEncode(slots.map((s) => s.toJson()).toList()),
  );

  NotificationSlot? slotById(String id) {
    for (final slot in readSlots()) {
      if (slot.id == id) return slot;
    }
    return null;
  }

  // ── Delivered (history) ────────────────────────────────────────────────

  List<DeliveredNotification> readDelivered() {
    final raw = storage.get<String>(_box, _deliveredKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => DeliveredNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeDelivered(List<DeliveredNotification> items) => storage.put(
    _box,
    _deliveredKey,
    jsonEncode(items.map((d) => d.toJson()).toList()),
  );

  // ── Schema ─────────────────────────────────────────────────────────────

  static const _schemaKey = 'schema';
  static const _schemaVersion = 3;

  /// History written by earlier builds recorded notifications that were
  /// never actually scheduled (scheduling failed silently), so it can't be
  /// trusted. Wiped once when the schema version moves.
  Future<void> resetHistoryIfOutdated() async {
    if ((storage.get<int>(_box, _schemaKey) ?? 0) >= _schemaVersion) return;
    await storage.delete(_box, _slotsKey);
    await storage.delete(_box, _deliveredKey);
    await storage.delete(_box, _readKey);
    await storage.put(_box, _schemaKey, _schemaVersion);
  }

  // ── Read state ─────────────────────────────────────────────────────────

  Set<String> readIds() {
    final raw = storage.get<String>(_box, _readKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> writeReadIds(Set<String> ids) =>
      storage.put(_box, _readKey, jsonEncode(ids.toList()));
}
