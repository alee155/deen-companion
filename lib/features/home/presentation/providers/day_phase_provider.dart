import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';

/// The part of the day the Home header artwork is themed for.
///
/// It follows the prayers: morning runs from Fajr until Asr, evening from Asr
/// until Maghrib, and night from Maghrib until the next Fajr.
enum DayPhase {
  morning('assets/images/morning_view.gif'),
  evening('assets/images/evening_view.gif'),
  night('assets/images/night_view.gif');

  final String gifAsset;
  const DayPhase(this.gifAsset);
}

/// Hour (0–23, local time) at which each period begins when today's prayer
/// times are not known (no location yet, or nothing loaded). Night wraps past
/// midnight, so it runs from [nightStartHour] until [morningStartHour].
const int morningStartHour = 5;
const int eveningStartHour = 16;
const int nightStartHour = 20;

/// Whether [times] describe the day [now] is in: from the evening before
/// (night, until Fajr) up to the next Fajr. Times left over from yesterday are
/// not used, or the hours after midnight would be themed from the wrong day.
bool _covers(PrayerTimes times, DateTime now) {
  final end = times.nextFajr ?? times.fajr.add(const Duration(days: 1));
  return !now.isBefore(times.fajr.subtract(const Duration(hours: 12))) &&
      now.isBefore(end);
}

/// The phase at [time]. With today's prayer [times] it follows Fajr, Asr and
/// Maghrib; without them (or with times for another day) it falls back to the
/// fixed hours above.
DayPhase dayPhaseAt(DateTime time, {PrayerTimes? times}) {
  if (times != null && _covers(times, time)) {
    if (!time.isBefore(times.maghrib)) return DayPhase.night;
    if (!time.isBefore(times.asr)) return DayPhase.evening;
    if (!time.isBefore(times.fajr)) return DayPhase.morning;
    return DayPhase.night;
  }
  final hour = time.hour;
  if (hour >= nightStartHour || hour < morningStartHour) return DayPhase.night;
  if (hour >= eveningStartHour) return DayPhase.evening;
  return DayPhase.morning;
}

/// The next moment [dayPhaseAt] can change after [now].
DateTime nextDayPhaseChange(DateTime now, {PrayerTimes? times}) {
  if (times != null && _covers(times, now)) {
    for (final boundary in [times.fajr, times.asr, times.maghrib]) {
      if (boundary.isAfter(now)) return boundary;
    }
    return times.nextFajr ?? times.fajr.add(const Duration(days: 1));
  }
  for (final hour in const [
    morningStartHour,
    eveningStartHour,
    nightStartHour,
  ]) {
    final boundary = DateTime(now.year, now.month, now.day, hour);
    if (boundary.isAfter(now)) return boundary;
  }
  return DateTime(now.year, now.month, now.day + 1, morningStartHour);
}

/// Emits the current [DayPhase] and updates itself the moment the period
/// changes, so a Home screen left open across Asr or Maghrib needs no restart.
///
/// A single timer sleeps until the next boundary rather than polling. Timers
/// can be paused or delayed while the app is backgrounded, so the period is
/// also re-read on resume. When the prayer times change (a new day, a new
/// place or calculation method) the notifier rebuilds with the new boundaries.
class DayPhaseNotifier extends Notifier<DayPhase> {
  Timer? _timer;
  PrayerTimes? _times;

  DateTime Function() get clock => ref.read(dayPhaseClockProvider);

  @override
  DayPhase build() {
    _times = ref.watch(prayerTimesNotifierProvider).valueOrNull;
    final lifecycle = _ResumeListener(_sync);
    WidgetsBinding.instance.addObserver(lifecycle);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(lifecycle);
    });
    _schedule();
    return dayPhaseAt(clock(), times: _times);
  }

  void _schedule() {
    _timer?.cancel();
    final now = clock();
    // Small cushion so the timer never fires just before the boundary.
    final wait =
        nextDayPhaseChange(now, times: _times).difference(now) +
        const Duration(milliseconds: 250);
    _timer = Timer(wait, _sync);
  }

  void _sync() {
    state = dayPhaseAt(clock(), times: _times);
    _schedule();
  }
}

class _ResumeListener with WidgetsBindingObserver {
  final VoidCallback onResume;
  _ResumeListener(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) onResume();
  }
}

final dayPhaseProvider = NotifierProvider<DayPhaseNotifier, DayPhase>(
  DayPhaseNotifier.new,
);

/// The clock [dayPhaseProvider] reads; overridden in tests.
final dayPhaseClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
