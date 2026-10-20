import 'package:fake_async/fake_async.dart';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/theme/app_colors.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_provider.dart';
import 'package:deen_companion/features/theme/domain/theme_schedule.dart';
import 'package:deen_companion/features/theme/presentation/providers/theme_period_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/fake_storage.dart';

DateTime t(int h, [int m = 0]) => DateTime(2026, 6, 10, h, m);

final _times = PrayerTimes(
  fajr: t(4),
  sunrise: t(5, 30),
  dhuhr: t(12, 30),
  asr: t(16),
  maghrib: t(19, 30),
  isha: t(21),
  hijriDate: '',
  nextFajr: DateTime(2026, 6, 11, 4, 1),
);

class _FakeTimes extends PrayerTimesNotifier {
  _FakeTimes(this.value);
  final PrayerTimes? value;

  @override
  Stream<PrayerTimes> build() =>
      value == null ? const Stream.empty() : Stream.value(value!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeStorage storage;
  late DateTime now;

  ProviderContainer make({PrayerTimes? times}) {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        themeClockProvider.overrideWithValue(() => now),
        prayerTimesNotifierProvider.overrideWith(() => _FakeTimes(times)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    storage = FakeStorage();
    now = t(17);
  });

  void choose(String v) => storage.boxes[AppConstants.settingsBoxName] = {
    AppConstants.themeModeKey: v,
  };

  test('manual Light and Dark ignore the time of day entirely', () async {
    choose('dark');
    final c = make(times: _times);
    await c.read(prayerTimesNotifierProvider.future);
    expect(c.read(activeThemeVariantProvider), ThemeVariant.dark);
  });

  test('manual Light is returned as Light at night', () {
    choose('light');
    now = t(23);
    expect(make().read(activeThemeVariantProvider), ThemeVariant.light);
  });

  test('automatic follows the prayer period from server times', () async {
    choose('automatic');
    final c = make(times: _times);
    await c.read(prayerTimesNotifierProvider.future);
    expect(c.read(activeThemeVariantProvider), ThemeVariant.asr);
  });

  test('automatic works without prayer times (approximate day)', () {
    choose('automatic');
    now = t(13);
    expect(make().read(activeThemeVariantProvider), ThemeVariant.dhuhr);
  });

  test('the period moves on by itself when a boundary passes', () {
    fakeAsync((async) {
      choose('automatic');
      final start = t(15, 59);
      now = start;
      final c = make(times: _times);
      c.read(prayerTimesNotifierProvider);
      async.flushMicrotasks();
      expect(c.read(themePeriodProvider), ThemePeriod.dhuhr);

      async.elapse(const Duration(minutes: 2));
      now = start.add(const Duration(minutes: 2));
      expect(c.read(themePeriodProvider), ThemePeriod.asr);
      c.dispose();
    });
  });

  test('maps every period to its own look', () {
    final seen = {for (final p in ThemePeriod.values) variantForPeriod(p)};
    expect(seen.length, ThemePeriod.values.length);
    expect(variantForPeriod(ThemePeriod.maghrib), ThemeVariant.maghrib);
  });
}
