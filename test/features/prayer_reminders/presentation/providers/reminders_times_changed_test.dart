import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_reminders/data/prayer_alarm_channel.dart';
import 'package:deen_companion/features/prayer_reminders/presentation/providers/reminders_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockChannel extends Mock implements PrayerAlarmChannel {}

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

/// Reminders must follow the prayer times: when a refresh brings different
/// times, the armed alarms have to be rebuilt from them.
void main() {
  late PaStorage storage;
  late FakePrayerRepo repo;
  late _MockChannel channel;
  var pushCount = 0;

  setUpAll(() {
    initFlavorForTests();
    registerFallbackValue(<PrayerAlarmEntry>[]);
  });

  setUp(() {
    storage = PaStorage();
    repo = FakePrayerRepo();
    channel = _MockChannel();
    pushCount = 0;
    when(() => channel.cancelAll()).thenAnswer((_) async {});
    when(
      () => channel.pushSchedule(
        any(),
        snoozeMinutes: any(named: 'snoozeMinutes'),
      ),
    ).thenAnswer((_) async {
      pushCount++;
      return 5;
    });
    repo.months[1] = Success([_upcoming()]);
  });

  ProviderContainer make({bool enabled = true}) {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        prayerTimesRepositoryProvider.overrideWithValue(repo),
        prayerTimesLoaderProvider.overrideWith(
          (ref) => FakePrayerTimesLoader(ref, repo),
        ),
        prayerAlarmChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> armed({bool enabled = true}) async {
    final c = make();
    if (enabled) await c.read(remindersEnabledProvider.notifier).set(true);
    // The service must exist for its listener to be active (bootstrap reads it).
    c.read(prayerReminderServiceProvider);
    return c;
  }

  int pushes() => pushCount;

  void timesChanged(ProviderContainer c) =>
      c.read(prayerTimesUpdatedProvider.notifier).state++;

  test('changed prayer times re-arm the alarms', () async {
    final c = await armed();
    timesChanged(c);
    await _settle();
    expect(pushes(), 1);
  });

  test('each change re-arms again', () async {
    final c = await armed();
    timesChanged(c);
    await _settle();
    timesChanged(c);
    await _settle();
    expect(pushes(), 2);
  });

  test('with reminders off, a change arms nothing', () async {
    final c = await armed(enabled: false);
    timesChanged(c);
    await _settle();
    expect(pushes(), 0);
  });

  test('a burst of changes collapses instead of stacking up', () async {
    final c = await armed();
    for (var i = 0; i < 5; i++) {
      timesChanged(c);
    }
    await _settle();
    expect(pushes(), lessThanOrEqualTo(2), reason: 'one run plus one rerun');
    expect(pushes(), greaterThanOrEqualTo(1));
  });

  test('the new alarms are built from the new times', () async {
    final c = await armed();
    // Times move 30 minutes earlier, as if the user changed the method.
    final shifted = _upcoming();
    final earlier = PrayerTimes(
      fajr: shifted.fajr.subtract(const Duration(minutes: 30)),
      dhuhr: shifted.dhuhr,
      asr: shifted.asr,
      maghrib: shifted.maghrib,
      isha: shifted.isha,
      hijriDate: '',
    );
    repo.months[1] = Success([earlier]);
    timesChanged(c);
    await _settle();

    final entries =
        verify(
              () => channel.pushSchedule(
                captureAny(),
                snoozeMinutes: any(named: 'snoozeMinutes'),
              ),
            ).captured.single
            as List<PrayerAlarmEntry>;
    final fajr = entries.firstWhere((e) => e.prayerName == 'fajr');
    expect(
      fajr.triggerAt.millisecondsSinceEpoch,
      earlier.fajr.millisecondsSinceEpoch,
    );
  });

  test('no prayer times available does not crash or cancel', () async {
    repo.months.clear();
    final c = await armed();
    timesChanged(c);
    await _settle();
    expect(pushes(), 0);
    verifyNever(() => channel.cancelAll());
  });

  test(
    'the same times arriving again do not re-arm (the signal is not raised)',
    () async {
      final c = await armed();
      await _settle();
      expect(pushes(), 0);
      expect(c.read(prayerTimesUpdatedProvider), 0);
    },
  );
}
