import 'dart:ui' show AppLifecycleState;

import 'package:deen_companion/features/home/presentation/providers/day_phase_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int h, [int m = 0, int day = 10]) => DateTime(2026, 6, day, h, m);

/// Today's times: Fajr 04:00, Asr 16:00, Maghrib 19:30.
final _times = PrayerTimes(
  fajr: d(4),
  sunrise: d(5, 30),
  dhuhr: d(12, 30),
  asr: d(16),
  maghrib: d(19, 30),
  isha: d(21),
  hijriDate: '',
  nextFajr: d(4, 1, 11),
);

class _FakeTimes extends PrayerTimesNotifier {
  _FakeTimes(this.value);
  final PrayerTimes? value;

  @override
  Stream<PrayerTimes> build() =>
      value == null ? const Stream.empty() : Stream.value(value!);
}

void main() {
  group('dayPhaseAt with prayer times', () {
    DayPhase at(int h, [int m = 0]) => dayPhaseAt(d(h, m), times: _times);

    test(
      'morning is Fajr until Asr, evening Asr until Maghrib, then night',
      () {
        expect(at(0), DayPhase.night);
        expect(at(3, 59), DayPhase.night);
        expect(at(4), DayPhase.morning);
        expect(at(10), DayPhase.morning);
        expect(at(15, 59), DayPhase.morning);
        expect(at(16), DayPhase.evening);
        expect(at(19, 29), DayPhase.evening);
        expect(at(19, 30), DayPhase.night);
        expect(at(23, 59), DayPhase.night);
      },
    );

    test('it follows the prayers, not the clock: a late Asr stays morning', () {
      final winter = PrayerTimes(
        fajr: d(6),
        dhuhr: d(12),
        asr: d(15, 10),
        maghrib: d(17, 5),
        isha: d(18, 30),
        hijriDate: '',
        nextFajr: d(6, 0, 11),
      );
      // 16:00 is evening by the fixed hours, but here Asr was at 15:10 and
      // Maghrib is at 17:05.
      expect(dayPhaseAt(d(15, 5), times: winter), DayPhase.morning);
      expect(dayPhaseAt(d(15, 10), times: winter), DayPhase.evening);
      expect(dayPhaseAt(d(17, 5), times: winter), DayPhase.night);
      // 19:00 is "evening" by the fixed hours; it is night here.
      expect(dayPhaseAt(d(19), times: winter), DayPhase.night);
    });

    test('yesterday\'s times are not used the next morning', () {
      // 06:00 the next day, times still from the 10th: Maghrib (19:30) has
      // "passed", which would wrongly say night. The fixed hours say morning.
      expect(dayPhaseAt(d(6, 0, 11), times: _times), DayPhase.morning);
    });
  });

  group('dayPhaseAt without prayer times (fixed hours)', () {
    DayPhase at(int h, [int m = 0]) => dayPhaseAt(DateTime(2026, 1, 1, h, m));

    test('maps hours to phases at the boundaries', () {
      expect(at(0), DayPhase.night);
      expect(at(4, 59), DayPhase.night);
      expect(at(5), DayPhase.morning);
      expect(at(15, 59), DayPhase.morning);
      expect(at(16), DayPhase.evening);
      expect(at(19, 59), DayPhase.evening);
      expect(at(20), DayPhase.night);
      expect(at(23, 59), DayPhase.night);
    });
  });

  group('nextDayPhaseChange', () {
    test(
      'with prayer times it is the next of Fajr, Asr, Maghrib, next Fajr',
      () {
        expect(nextDayPhaseChange(d(2), times: _times), d(4));
        expect(nextDayPhaseChange(d(10), times: _times), d(16));
        expect(nextDayPhaseChange(d(17), times: _times), d(19, 30));
        expect(nextDayPhaseChange(d(22), times: _times), d(4, 1, 11));
      },
    );

    test('without them it is the next fixed boundary', () {
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 10)),
        DateTime(2026, 1, 1, 16),
      );
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 16)),
        DateTime(2026, 1, 1, 20),
      );
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 22)),
        DateTime(2026, 1, 2, 5),
      );
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 2)),
        DateTime(2026, 1, 1, 5),
      );
    });
  });

  group('the GIFs', () {
    test('each phase has its own view GIF', () {
      expect(DayPhase.morning.gifAsset, 'assets/images/morning_view.gif');
      expect(DayPhase.evening.gifAsset, 'assets/images/evening_view.gif');
      expect(DayPhase.night.gifAsset, 'assets/images/night_view.gif');
    });
  });

  group('dayPhaseProvider', () {
    ProviderContainer make(DateTime Function() clock, PrayerTimes? times) =>
        ProviderContainer(
          overrides: [
            dayPhaseClockProvider.overrideWithValue(clock),
            prayerTimesNotifierProvider.overrideWith(() => _FakeTimes(times)),
          ],
        );

    testWidgets('moves to evening when Asr passes', (tester) async {
      var now = d(15, 59, 10).add(const Duration(seconds: 30));
      final container = make(() => now, _times);
      await container.read(prayerTimesNotifierProvider.future);

      final seen = <DayPhase>[];
      container.listen(dayPhaseProvider, (_, next) => seen.add(next));
      expect(container.read(dayPhaseProvider), DayPhase.morning);

      now = d(16, 0).add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 31));

      expect(container.read(dayPhaseProvider), DayPhase.evening);
      expect(seen, [DayPhase.evening]);
      container.dispose();
    });

    testWidgets('moves to night at Maghrib', (tester) async {
      var now = d(19, 29, 10).add(const Duration(seconds: 30));
      final container = make(() => now, _times);
      await container.read(prayerTimesNotifierProvider.future);
      container.listen(dayPhaseProvider, (_, _) {});
      expect(container.read(dayPhaseProvider), DayPhase.evening);

      now = d(19, 30).add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 31));

      expect(container.read(dayPhaseProvider), DayPhase.night);
      container.dispose();
    });

    testWidgets('without prayer times it uses the fixed hours', (tester) async {
      var now = DateTime(2026, 1, 1, 15, 59, 30);
      final container = make(() => now, null);

      final seen = <DayPhase>[];
      container.listen(dayPhaseProvider, (_, next) => seen.add(next));
      expect(container.read(dayPhaseProvider), DayPhase.morning);

      now = DateTime(2026, 1, 1, 16, 0, 1);
      await tester.pump(const Duration(seconds: 31));

      expect(container.read(dayPhaseProvider), DayPhase.evening);
      expect(seen, [DayPhase.evening]);
      container.dispose();
    });

    testWidgets('re-syncs on app resume', (tester) async {
      var now = d(10);
      final container = make(() => now, _times);
      await container.read(prayerTimesNotifierProvider.future);
      container.listen(dayPhaseProvider, (_, _) {});
      expect(container.read(dayPhaseProvider), DayPhase.morning);

      now = d(21);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(container.read(dayPhaseProvider), DayPhase.night);
      container.dispose();
    });

    testWidgets('new prayer times replace the fixed hours when they arrive', (
      tester,
    ) async {
      // 16:30 is evening by the fixed hours; with these times Asr is at 17:00.
      final late = PrayerTimes(
        fajr: d(4),
        dhuhr: d(13),
        asr: d(17),
        maghrib: d(20, 30),
        isha: d(22),
        hijriDate: '',
        nextFajr: d(4, 0, 11),
      );
      final now = d(16, 30);
      final container = make(() => now, late);
      container.listen(dayPhaseProvider, (_, _) {});
      // Before the times load: the fixed hours.
      expect(container.read(dayPhaseProvider), DayPhase.evening);

      await container.read(prayerTimesNotifierProvider.future);
      await tester.pump(const Duration(milliseconds: 10));

      expect(container.read(dayPhaseProvider), DayPhase.morning);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
