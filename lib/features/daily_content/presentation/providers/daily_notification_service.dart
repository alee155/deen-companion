import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/notification_permission_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/logger.dart';
import '../../../prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import '../../../prayer_times/presentation/providers/upcoming_prayer_days.dart';
import '../../data/daily_notification_scheduler.dart';
import '../../data/daily_content_store.dart';
import '../../domain/daily_content_selector.dart';
import '../../domain/notification_text.dart';
import 'daily_content_providers.dart';

/// Owns the daily Ayat & Hadith notification end to end: arms the rolling
/// schedule (Fajr + configured offset), keeps it fresh, and routes taps.
///
/// Same shape as [PrayerReminderService] / `AppOpenAdManager`: a small
/// `Ref`-holding service, started once from `bootstrap.dart`. Scheduling is a
/// full cancel-and-replace of a multi-day window handed to
/// `flutter_local_notifications`, which registers OS alarms and re-arms them
/// after reboot — so the notification arrives with the app closed.
class DailyNotificationService with WidgetsBindingObserver {
  final Ref ref;
  DailyNotificationService(this.ref);

  bool _started = false;
  bool _syncing = false;
  bool _syncAgain = false;

  /// A notification tap received before the router could safely navigate
  /// (cold start: Splash still running, or the Welcome gate not passed).
  String? _pendingTapId;
  bool _routerReady = false;

  Timer? _refreshTimer;

  DailyNotificationScheduler get _scheduler =>
      ref.read(dailyNotificationSchedulerProvider);
  DailyContentStore get _store => ref.read(dailyContentStoreProvider);

  /// Call once at launch. Does not prompt for permission (the Splash is
  /// still on screen) — see [onHomeReady].
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(() async {
      await _store.resetHistoryIfOutdated();
      await _scheduler.init(onTap: _handleTap);
      final initial = await _scheduler.launchPayload();
      if (initial != null) _handleTap(initial);
      await refreshHistory();
      await sync();
    }());
  }

  bool _homeReadyHandled = false;

  /// Called when Home first mounts (returning users after Splash, new users
  /// after the Welcome gate): the router can now take pushes and any tap
  /// queued during launch is delivered. Permissions are not asked here —
  /// the upfront setup flow on Home owns that.
  Future<void> onHomeReady() async {
    if (_homeReadyHandled) return;
    _homeReadyHandled = true;
    _routerReady = true;
    final pending = _pendingTapId;
    _pendingTapId = null;
    if (pending != null) _open(pending);
    await sync();
  }

  // ── Taps ───────────────────────────────────────────────────────────────

  void _handleTap(String id) {
    unawaited(() async {
      await refreshHistory();
      await ref.read(notificationHistoryProvider.notifier).markRead(id);
    }());
    if (!_routerReady) {
      _pendingTapId = id;
      return;
    }
    _open(id);
  }

  void _open(String id) {
    ref
        .read(appRouterProvider)
        .push('/daily-content?id=${Uri.encodeQueryComponent(id)}');
  }

  // ── Scheduling ─────────────────────────────────────────────────────────

  /// Re-arms the window if the feature is on and permitted; otherwise makes
  /// sure nothing stays armed. Concurrent calls coalesce into one re-run.
  Future<void> sync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _syncOnce();
      } while (_syncAgain);
    } catch (error, stackTrace) {
      AppLogger.e('Daily notification sync failed', error, stackTrace);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    final now = DateTime.now();
    final enabled = ref.read(dailyNotificationEnabledProvider);
    final permitted = await ref
        .read(notificationPermissionServiceProvider)
        .isGranted();

    if (!enabled || !permitted) {
      await _scheduler.cancelAll();
      await _replaceFutureSlots(now, const []);
      return;
    }

    final config = ref.read(dailyNotificationConfigProvider);
    final loaded = await loadUpcomingPrayerDays(
      ref,
      now: now,
      windowDays: config.windowDays,
    );
    if (loaded.days.isEmpty) {
      // No prayer times (offline, no location yet): keep whatever is already
      // armed rather than cancelling a working schedule.
      AppLogger.i('Daily notification: no prayer times — schedule unchanged');
      return;
    }

    // One slot per calendar day, at Fajr + offset, future only.
    final byDay = <String, DateTime>{};
    for (final day in loaded.days) {
      final at = day.fajr.add(config.offsetAfterFajr);
      if (!at.isAfter(now)) continue;
      byDay.putIfAbsent(DailyContentSelector.dateKey(day.fajr), () => at);
    }
    final dayKeys = byDay.keys.toList()..sort();

    // Resolve content ahead of time so the notification can carry a real
    // preview. Cached per day, so this fetches only days not seen yet (in
    // steady state: one new day per sync). A failed day just gets the
    // generic wording; the screen fetches on open.
    final repository = ref.read(dailyContentRepositoryProvider);
    await Future.wait(
      dayKeys
          .where((k) => repository.getCached(k) == null)
          .map(repository.fetch),
    );

    final entries = [
      for (final key in dayKeys)
        DailyNotificationEntry(
          id: key,
          triggerAt: byDay[key]!,
          title: config.title,
          body: DailyNotificationText.preview(repository.getCached(key)),
        ),
    ];

    final armed = await _scheduler.scheduleAll(entries);

    await _replaceFutureSlots(now, [
      for (final e in entries.where((e) => armed.contains(e.id)))
        NotificationSlot(
          id: e.id,
          dateKey: e.id,
          epochMillis: e.triggerAt.millisecondsSinceEpoch,
        ),
    ]);
    AppLogger.i(
      'Daily notification: scheduled ${armed.length}/${entries.length} day(s)',
    );

    final cutoff = now.subtract(const Duration(days: 14));
    await repository.pruneBefore(DailyContentSelector.dateKey(cutoff));
  }

  /// Keeps delivered slots (history), drops not-yet-due real ones, adds the
  /// fresh set. Debug slots are never touched here.
  Future<void> _replaceFutureSlots(
    DateTime now,
    List<NotificationSlot> fresh,
  ) async {
    final keep = _store.readSlots().where(
      (s) => s.debug || !s.time.isAfter(now),
    );
    final cutoff = now
        .subtract(const Duration(days: 60))
        .millisecondsSinceEpoch;
    final merged = [...keep.where((s) => s.epochMillis >= cutoff), ...fresh];
    await _store.writeSlots(merged);
    ref.read(notificationHistoryProvider.notifier).refresh();
  }

  // ── History ────────────────────────────────────────────────────────────

  /// Reconciles history with what the OS actually did. A scheduled slot
  /// whose time has passed and which is no longer pending with the plugin has
  /// fired — the plugin drops a one-shot notification from its pending list
  /// when it posts it. Slots still pending after their time (alarm blocked or
  /// deferred) are NOT recorded, so the list never claims a delivery that
  /// didn't happen. Idempotent: rows are keyed by notification id.
  Future<void> refreshHistory() async {
    final now = DateTime.now();
    final permitted = await ref
        .read(notificationPermissionServiceProvider)
        .isGranted();
    final pending = await _scheduler.pendingIds();

    if (permitted) {
      final byId = {for (final d in _store.readDelivered()) d.id: d};
      var changed = false;
      for (final slot in _store.readSlots()) {
        if (slot.time.isAfter(now)) continue;
        if (pending.contains(slot.id) || byId.containsKey(slot.id)) continue;
        byId[slot.id] = DeliveredNotification(
          id: slot.id,
          dateKey: slot.dateKey,
          deliveredAtMillis: slot.epochMillis,
          debug: slot.debug,
        );
        changed = true;
      }
      if (changed) await _store.writeDelivered(byId.values.toList());
    }
    ref.read(notificationHistoryProvider.notifier).refresh();
    _armRefreshTimer();

    // A delivery whose content was never cached (offline when scheduled)
    // gets its preview filled in now, then the list re-renders once.
    final repository = ref.read(dailyContentRepositoryProvider);
    final missing = _store
        .readDelivered()
        .map((d) => d.dateKey)
        .toSet()
        .where((k) => repository.getCached(k) == null);
    if (missing.isEmpty) return;
    await Future.wait(missing.map(repository.fetch));
    ref.read(notificationHistoryProvider.notifier).refresh();
  }

  /// While the app is open, reconcile shortly after the next slot's time so
  /// the bell badge and list update without waiting for a resume.
  void _armRefreshTimer() {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    DateTime? next;
    for (final slot in _store.readSlots()) {
      if (slot.time.isAfter(now) &&
          (next == null || slot.time.isBefore(next))) {
        next = slot.time;
      }
    }
    if (next == null) return;
    final wait = next.difference(now) + const Duration(seconds: 3);
    if (wait > const Duration(hours: 24)) return; // resume covers longer gaps
    _refreshTimer = Timer(wait, () => unawaited(refreshHistory()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(refreshHistory());
    if (_routerReady) unawaited(sync());
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _started = false;
  }
}

final dailyNotificationServiceProvider = Provider<DailyNotificationService>((
  ref,
) {
  final service = DailyNotificationService(ref);
  // Prayer-time inputs changed (method / school) → Fajr moved → re-arm.
  ref.listen(prayerCalculationSettingsProvider, (_, _) => service.sync());
  // Toggled in Settings.
  ref.listen(dailyNotificationEnabledProvider, (_, _) => service.sync());
  ref.onDispose(service.dispose);
  return service;
});
