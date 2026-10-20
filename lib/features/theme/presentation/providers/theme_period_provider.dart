import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';
import '../../domain/theme_schedule.dart';

/// The clock the automatic theme reads. Overridden in tests.
final themeClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// The current [ThemePeriod], kept up to date by a single timer aimed at the
/// next boundary (not a per-second tick). It re-reads the schedule whenever
/// the prayer times change (city, method, a fresh fetch) and when the app
/// returns to the foreground, since timers can be late in the background.
class ThemePeriodNotifier extends Notifier<ThemePeriod> {
  Timer? _timer;
  _ResumeListener? _lifecycle;

  /// Re-check at least this often when the schedule gives no next boundary.
  static const _idleRecheck = Duration(minutes: 15);

  @override
  ThemePeriod build() {
    final times = ref.watch(prayerTimesNotifierProvider).value;
    final now = ref.read(themeClockProvider)();
    final schedule = ThemeSchedule.forNow(times, now);

    final next = schedule.nextChangeAfter(now);
    _timer?.cancel();
    _timer = Timer(
      next == null ? _idleRecheck : next.difference(now),
      ref.invalidateSelf,
    );

    _lifecycle ??= _ResumeListener(ref.invalidateSelf)..attach();
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.detach();
      _lifecycle = null;
    });
    return schedule.periodAt(now);
  }
}

class _ResumeListener with WidgetsBindingObserver {
  _ResumeListener(this.onResume);
  final VoidCallback onResume;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

final themePeriodProvider = NotifierProvider<ThemePeriodNotifier, ThemePeriod>(
  ThemePeriodNotifier.new,
);

ThemeVariant variantForPeriod(ThemePeriod p) => switch (p) {
  ThemePeriod.fajr => ThemeVariant.fajr,
  ThemePeriod.sunrise => ThemeVariant.sunrise,
  ThemePeriod.dhuhr => ThemeVariant.dhuhr,
  ThemePeriod.asr => ThemeVariant.asr,
  ThemePeriod.maghrib => ThemeVariant.maghrib,
  ThemePeriod.isha => ThemeVariant.isha,
};

/// The one thing the root widget watches: the look to wear right now. A manual
/// Light/Dark choice is returned as-is and never touches prayer data; the
/// period is only watched (so only fetched and timed) in automatic mode.
final activeThemeVariantProvider = Provider<ThemeVariant>((ref) {
  final choice = ref.watch(themeModeNotifierProvider);
  return switch (choice) {
    AppThemeChoice.light => ThemeVariant.light,
    AppThemeChoice.dark => ThemeVariant.dark,
    AppThemeChoice.automatic => variantForPeriod(
      ref.watch(themePeriodProvider),
    ),
  };
});
