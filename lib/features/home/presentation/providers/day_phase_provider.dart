import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The part of the day the Home header artwork is themed for.
enum DayPhase {
  morning('assets/images/morning_mosque_760.gif'),
  evening('assets/images/evening_mosque_760.gif'),
  night('assets/images/night_mosque_760.gif');

  final String gifAsset;
  const DayPhase(this.gifAsset);
}

/// Hour (0–23, local time) at which each period begins. Night wraps past
/// midnight, so it runs from [nightStartHour] until [morningStartHour].
const int morningStartHour = 5;
const int eveningStartHour = 16;
const int nightStartHour = 20;

DayPhase dayPhaseAt(DateTime time) {
  final hour = time.hour;
  if (hour >= nightStartHour || hour < morningStartHour) return DayPhase.night;
  if (hour >= eveningStartHour) return DayPhase.evening;
  return DayPhase.morning;
}

/// The next moment [dayPhaseAt] can change after [now].
DateTime nextDayPhaseChange(DateTime now) {
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
/// changes, so a Home screen left open across sunset needs no restart.
///
/// A single timer sleeps until the next boundary rather than polling. Timers
/// can be paused or delayed while the app is backgrounded, so the period is
/// also re-read on resume.
class DayPhaseNotifier extends Notifier<DayPhase> {
  Timer? _timer;
  late final _ResumeListener _lifecycle;

  DateTime Function() get clock => ref.read(dayPhaseClockProvider);

  @override
  DayPhase build() {
    _lifecycle = _ResumeListener(_sync);
    WidgetsBinding.instance.addObserver(_lifecycle);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(_lifecycle);
    });
    _schedule();
    return dayPhaseAt(clock());
  }

  void _schedule() {
    _timer?.cancel();
    final now = clock();
    // Small cushion so the timer never fires just before the boundary.
    final wait =
        nextDayPhaseChange(now).difference(now) +
        const Duration(milliseconds: 250);
    _timer = Timer(wait, _sync);
  }

  void _sync() {
    state = dayPhaseAt(clock());
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
