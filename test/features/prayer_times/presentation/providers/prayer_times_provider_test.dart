import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/upcoming_prayer_days.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';

class _NoRecovery extends LocationRecoveryNotifier {
  @override
  int build() => 0;
}

ProviderContainer makeContainer(FakePrayerRepo repo, {PaStorage? storage}) {
  final c = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage ?? PaStorage()),
      prayerTimesRepositoryProvider.overrideWithValue(repo),
      locationRecoveryProvider.overrideWith(_NoRecovery.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  late FakePrayerRepo repo;
  setUp(() => repo = FakePrayerRepo());

  group('PrayerTimesNotifier', () {
    test('no cache: emits fresh data and uses current settings ids', () async {
      final c = makeContainer(repo);
      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setMethod(PrayerCalculationMethod.karachi);
      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setSchool(AsrSchool.hanafi);

      final v = await c.read(prayerTimesNotifierProvider.future);
      expect(v, pt(30));
      expect(repo.lastMethod, 1);
      expect(repo.lastSchool, 1);
    });

    test('cache present: emits cache first then the fresh value', () async {
      repo.cached = pt(29);
      repo.fetchResult = Success(pt(30));
      final c = makeContainer(repo);
      final seen = <PrayerTimes>[];
      final sub = c.listen(prayerTimesNotifierProvider, (_, n) {
        if (n.hasValue) seen.add(n.value!);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await c.read(prayerTimesNotifierProvider.future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(seen.first, pt(29));
      expect(seen.last, pt(30));
    });

    test('failure with cache keeps the cache, no error state', () async {
      repo.cached = pt(29);
      repo.fetchResult = const Error(NetworkFailure());
      final c = makeContainer(repo);
      final v = await c.read(prayerTimesNotifierProvider.future);
      expect(v, pt(29));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(prayerTimesNotifierProvider).hasError, isFalse);
    });

    test('failure without cache surfaces the Failure', () async {
      repo.fetchResult = const Error(ServerFailure());
      final c = makeContainer(repo);
      await expectLater(
        c.read(prayerTimesNotifierProvider.future),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('changing calculation method refetches with the new id', () async {
      final c = makeContainer(repo);
      final sub = c.listen(prayerTimesNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(prayerTimesNotifierProvider.future);
      expect(repo.lastMethod, 3);
      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setMethod(PrayerCalculationMethod.egyptian);
      await c.read(prayerTimesNotifierProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(repo.lastMethod, 5);
      expect(repo.fetchCalls, 2);
    });
  });

  group('PrayerCalendarNotifier', () {
    test('passes year/month and settings, returns the list', () async {
      repo.months[10] = Success([pt(1), pt(2)]);
      final c = makeContainer(repo);
      final v = await c.read(
        prayerCalendarNotifierProvider((year: 2026, month: 10)).future,
      );
      expect(v, hasLength(2));
      expect(repo.monthCalls.single, (
        year: 2026,
        month: 10,
        method: 3,
        school: 0,
      ));
    });

    test('failure is thrown as the Failure', () async {
      final c = makeContainer(repo);
      await expectLater(
        c.read(prayerCalendarNotifierProvider((year: 2026, month: 11)).future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('loadUpcomingPrayerDays', () {
    final loader =
        Provider.family<Future<UpcomingPrayerDays>, ({DateTime now, int days})>(
          (ref, a) =>
              loadUpcomingPrayerDays(ref, now: a.now, windowDays: a.days),
        );

    test('window inside one month fetches that month once', () async {
      repo.months[9] = Success([pt(15), pt(16)]);
      final c = makeContainer(repo);
      final r = await c.read(loader((now: DateTime(2026, 9, 14), days: 7)));
      expect(r.error, isNull);
      expect(r.days, hasLength(2));
      expect(repo.monthCalls.map((e) => e.month), [9]);
    });

    test('window crossing a month boundary fetches both, in order', () async {
      repo.months[9] = Success([pt(29)]);
      repo.months[10] = Success([
        PrayerTimes(
          fajr: DateTime(2026, 10, 1, 5),
          dhuhr: DateTime(2026, 10, 1, 12),
          asr: DateTime(2026, 10, 1, 15),
          maghrib: DateTime(2026, 10, 1, 18),
          isha: DateTime(2026, 10, 1, 19),
          hijriDate: 'h',
        ),
      ]);
      final c = makeContainer(repo);
      final r = await c.read(loader((now: DateTime(2026, 9, 28), days: 7)));
      expect(repo.monthCalls.map((e) => e.month), [9, 10]);
      expect(r.days, hasLength(2));
    });

    test('year boundary uses the next year for the second month', () async {
      repo.months[12] = Success([pt(30)]);
      repo.months[1] = Success([pt(1)]);
      final c = makeContainer(repo);
      await c.read(loader((now: DateTime(2026, 12, 28), days: 7)));
      expect(repo.monthCalls.map((e) => (e.year, e.month)).toList(), [
        (2026, 12),
        (2027, 1),
      ]);
    });

    test(
      'all fetches fail, cache present -> falls back to cached day',
      () async {
        repo.cached = pt(30);
        final c = makeContainer(repo);
        final r = await c.read(loader((now: DateTime(2026, 9, 30), days: 1)));
        expect(r.error, isNull);
        expect(r.days, [pt(30)]);
      },
    );

    test('all fetches fail and no cache -> error message, no days', () async {
      final c = makeContainer(repo);
      final r = await c.read(loader((now: DateTime(2026, 9, 30), days: 1)));
      expect(r.days, isEmpty);
      expect(r.error, const NetworkFailure().message);
    });

    test(
      'first month ok, second fails -> keeps first month, no error',
      () async {
        repo.months[9] = Success([pt(29)]);
        final c = makeContainer(repo);
        final r = await c.read(loader((now: DateTime(2026, 9, 28), days: 7)));
        expect(r.error, isNull);
        expect(r.days, [pt(29)]);
      },
    );
  });
}
