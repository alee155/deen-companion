import 'dart:async';

import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/snaps/domain/snap_availability.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:deen_companion/features/snaps/presentation/snap_availability_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../prayer_logs/presentation/_prayer_log_test_support.dart';

NextPrayer _next(PrayerName p, {int hour = 17, int minute = 30}) =>
    NextPrayer(prayer: p, startsAt: DateTime(2026, 10, 28, hour, minute));

CurrentPrayer _open(PrayerName p, {required bool logged}) => CurrentPrayer(
  prayer: p,
  date: '2026-10-28',
  startsAt: DateTime(2026, 10, 28, 15),
  endsAt: DateTime(2026, 10, 28, 17),
  logged: logged,
  logId: logged ? 'l1' : null,
);

void main() {
  final now = DateTime(2026, 10, 28, 16);

  group('SnapAvailability.fromPrayer', () {
    test('an open prayer without its snap: available', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(PrayerName.asr, logged: false),
        ),
      );
      expect(a.isAvailable, isTrue);
      expect(a.reason, isNull);
    });

    test('an open prayer that already has its snap', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(PrayerName.asr, logged: true),
          next: _next(PrayerName.maghrib),
        ),
      );
      expect(a.isAvailable, isFalse);
      expect(a.reason, SnapUnavailableReason.alreadyLogged);
      expect(a.loggedPrayer, PrayerName.asr);
      expect(a.next?.prayer, PrayerName.maghrib);
    });

    test('no prayer open: the next one is kept for the message', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(now: now, next: _next(PrayerName.isha)),
      );
      expect(a.reason, SnapUnavailableReason.noPrayerOpen);
      expect(a.next?.prayer, PrayerName.isha);
    });

    test('times never synced: the server cannot say', () {
      final a = SnapAvailability.fromPrayer(CurrentPrayerState(now: now));
      expect(a.reason, SnapUnavailableReason.timesNotSynced);
    });
  });

  group('the wording', () {
    test('available: nothing to say', () {
      expect(const SnapAvailability.available().message, isNull);
    });

    test('no prayer open: explains the designated time, and when it opens', () {
      final m = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          next: _next(PrayerName.isha, hour: 19, minute: 5),
        ),
      ).message!;
      expect(
        m,
        startsWith('Snaps can only be sent while a prayer time is open.'),
      );
      expect(m, contains('Isha starts at 7:05 PM.'));
    });

    test('already sent: names the prayer and says it is one per prayer', () {
      final m = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(PrayerName.dhuhr, logged: true),
          next: _next(PrayerName.asr, hour: 15, minute: 45),
        ),
      ).message!;
      expect(m, contains('You’ve already sent your Dhuhr snap.'));
      expect(m, contains('one snap for each prayer'));
      expect(m, contains('Asr starts at 3:45 PM.'));
    });

    test(
      'already sent, with no next prayer known, still reads as a sentence',
      () {
        final m = SnapAvailability.fromPrayer(
          CurrentPrayerState(
            now: now,
            current: _open(PrayerName.isha, logged: true),
          ),
        ).message!;
        expect(m, contains('Isha snap'));
        expect(m, isNot(contains('starts at')));
        expect(m.trim(), endsWith('.'));
      },
    );

    test('times not synced: points the user to Prayer Times', () {
      final m = SnapAvailability.fromPrayer(
        CurrentPrayerState(now: now),
      ).message!;
      expect(m, contains('prayer times aren’t set up'));
      expect(m, contains('Prayer Times'));
    });

    test('still checking', () {
      expect(
        const SnapAvailability.checking().message,
        contains('Checking your prayer times'),
      );
    });

    test('no groups', () {
      expect(
        const SnapAvailability.noGroups().message,
        'Join or create a group to start sending snaps.',
      );
    });

    test('no reason reads as a generic error', () {
      for (final reason in SnapUnavailableReason.values) {
        final m = switch (reason) {
          SnapUnavailableReason.checking => const SnapAvailability.checking(),
          SnapUnavailableReason.noGroups => const SnapAvailability.noGroups(),
          SnapUnavailableReason.noPrayerOpen => SnapAvailability.fromPrayer(
            CurrentPrayerState(now: now, next: _next(PrayerName.fajr)),
          ),
          SnapUnavailableReason.alreadyLogged => SnapAvailability.fromPrayer(
            CurrentPrayerState(
              now: now,
              current: _open(PrayerName.asr, logged: true),
            ),
          ),
          SnapUnavailableReason.timesNotSynced => SnapAvailability.fromPrayer(
            CurrentPrayerState(now: now),
          ),
        }.message!;
        expect(m.toLowerCase(), isNot(contains('error')), reason: reason.name);
        expect(m.toLowerCase(), isNot(contains('something went wrong')));
        expect(
          m.length,
          greaterThan(25),
          reason: '${reason.name}: a real reason',
        );
      }
    });
  });

  group('snapAvailabilityProvider', () {
    ProviderContainer make(CurrentPrayerNotifier Function() notifier) {
      final c = ProviderContainer(
        overrides: [currentPrayerProvider.overrideWith(notifier)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('follows the server answer', () async {
      final c = make(
        () => FixedCurrent(
          CurrentPrayerState(
            now: now,
            current: _open(PrayerName.asr, logged: true),
          ),
        ),
      );
      await c.read(currentPrayerProvider.future);
      expect(
        c.read(snapAvailabilityProvider).reason,
        SnapUnavailableReason.alreadyLogged,
      );
    });

    test('while loading: checking', () {
      final c = make(_NeverLoads.new);
      expect(
        c.read(snapAvailabilityProvider).reason,
        SnapUnavailableReason.checking,
      );
    });

    test('a failed lookup leaves it to the server: available', () async {
      final c = make(_Fails.new);
      await expectLater(
        c.read(currentPrayerProvider.future),
        throwsA(anything),
      );
      expect(c.read(snapAvailabilityProvider).isAvailable, isTrue);
    });
  });
}

class _NeverLoads extends CurrentPrayerNotifier {
  @override
  Future<CurrentPrayerState> build() => Completer<CurrentPrayerState>().future;
}

class _Fails extends CurrentPrayerNotifier {
  @override
  Future<CurrentPrayerState> build() async => throw Exception('offline');
}
