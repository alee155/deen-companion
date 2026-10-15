import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_dnd/data/prayer_dnd_channel.dart';
import 'package:deen_companion/features/prayer_dnd/domain/dnd_window.dart';
import 'package:deen_companion/features/prayer_dnd/presentation/providers/prayer_dnd_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockChannel extends Mock implements PrayerDndChannel {}

PrayerTimes _upcoming() {
  final now = DateTime.now();
  DateTime at(int h) => now.add(Duration(hours: h));
  return PrayerTimes(
    fajr: at(1),
    dhuhr: at(2),
    asr: at(3),
    maghrib: at(4),
    isha: at(5),
    hijriDate: '',
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// Do Not Disturb windows follow the prayer times, so a refresh that brings
/// different times must re-plan them.
void main() {
  late PaStorage storage;
  late FakePrayerRepo repo;
  late _MockChannel channel;
  var pushCount = 0;

  setUpAll(() {
    initFlavorForTests();
    registerFallbackValue(<DndWindow>[]);
  });

  setUp(() {
    storage = PaStorage();
    repo = FakePrayerRepo();
    channel = _MockChannel();
    pushCount = 0;
    when(() => channel.cancelAll()).thenAnswer((_) async {});
    when(() => channel.pushSchedule(any())).thenAnswer((_) async {
      pushCount++;
      return 3;
    });
    repo.months[1] = Success([_upcoming()]);
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        prayerTimesRepositoryProvider.overrideWithValue(repo),
        prayerTimesLoaderProvider.overrideWith(
          (ref) => FakePrayerTimesLoader(ref, repo),
        ),
        prayerDndChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> ready({bool enabled = true}) async {
    final c = make();
    final n = c.read(dndSettingsProvider.notifier);
    await n.setDuration(PrayerName.dhuhr, 20);
    if (enabled) await n.setEnabled(true);
    c.read(prayerDndServiceProvider); // activates the listener
    return c;
  }

  int pushes() => pushCount;

  void timesChanged(ProviderContainer c) =>
      c.read(prayerTimesUpdatedProvider.notifier).state++;

  test('changed prayer times re-plan the windows', () async {
    final c = await ready();
    timesChanged(c);
    await _settle();
    expect(pushes(), 1);
  });

  test('with Do Not Disturb off, a change plans nothing', () async {
    final c = await ready(enabled: false);
    timesChanged(c);
    await _settle();
    expect(pushes(), 0);
  });

  test('a burst of changes collapses', () async {
    final c = await ready();
    for (var i = 0; i < 4; i++) {
      timesChanged(c);
    }
    await _settle();
    expect(pushes(), inInclusiveRange(1, 2));
  });

  test('the new windows start at the new times', () async {
    final c = await ready();
    final base = _upcoming();
    final moved = PrayerTimes(
      fajr: base.fajr,
      dhuhr: base.dhuhr.add(const Duration(minutes: 40)),
      asr: base.asr,
      maghrib: base.maghrib,
      isha: base.isha,
      hijriDate: '',
    );
    repo.months[1] = Success([moved]);
    timesChanged(c);
    await _settle();

    final windows =
        verify(() => channel.pushSchedule(captureAny())).captured.single
            as List<DndWindow>;
    final dhuhr = windows.firstWhere((w) => w.prayerName == 'dhuhr');
    expect(
      dhuhr.start.millisecondsSinceEpoch,
      moved.dhuhr.millisecondsSinceEpoch,
    );
  });

  test('nothing configured cancels instead of arming', () async {
    final c = make();
    await c.read(dndSettingsProvider.notifier).setEnabled(true);
    c.read(prayerDndServiceProvider);
    timesChanged(c);
    await _settle();
    expect(pushes(), 0);
    verify(() => channel.cancelAll()).called(1);
  });

  test('no prayer times available does not crash', () async {
    repo.months.clear();
    final c = await ready();
    timesChanged(c);
    await _settle();
    expect(pushes(), 0);
  });

  group('times shown next to each prayer', () {
    test('use the clock at the prayer location', () async {
      // Fajr 5 hours from now at an offset that differs from this machine's.
      final now = DateTime.now();
      final fajr = now.add(const Duration(hours: 1));
      const offset = Duration(hours: -3); // somewhere the phone is not
      final day = PrayerTimes(
        fajr: fajr,
        dhuhr: now.add(const Duration(hours: 2)),
        asr: now.add(const Duration(hours: 3)),
        maghrib: now.add(const Duration(hours: 4)),
        isha: now.add(const Duration(hours: 5)),
        hijriDate: '',
        utcOffset: offset,
      );
      repo.months[1] = Success([day]);
      final c = make();

      final shown = await c.read(dndUpcomingTimesProvider.future);

      final clock = shown[PrayerName.fajr]!;
      final expected = fajr.toUtc().add(offset);
      expect((clock.hour, clock.minute), (expected.hour, expected.minute));
    });

    test('the next occurrence is still decided by the real instant', () async {
      final now = DateTime.now();
      final past = PrayerTimes(
        fajr: now.subtract(const Duration(hours: 20)),
        dhuhr: now.subtract(const Duration(hours: 19)),
        asr: now.subtract(const Duration(hours: 18)),
        maghrib: now.subtract(const Duration(hours: 17)),
        isha: now.subtract(const Duration(hours: 16)),
        hijriDate: '',
      );
      repo.months[1] = Success([past, _upcoming()]);
      final shown = await make().read(dndUpcomingTimesProvider.future);
      final fajr = _upcoming().fajr;
      expect(shown[PrayerName.fajr]!.hour, fajr.hour);
    });
  });

  test('storage key sanity', () {
    expect(AppConstants.dndEnabledKey, isNotEmpty);
  });
}
