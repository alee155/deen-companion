import 'dart:async';

import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/snaps/domain/snap_availability.dart';
import 'package:deen_companion/features/special_days/domain/special_days.dart';
import 'package:deen_companion/features/special_days/presentation/providers/special_days_providers.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:deen_companion/features/snaps/presentation/snap_availability_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../prayer_logs/presentation/_prayer_log_test_support.dart';

NextPrayer _next(PrayerName p, {int hour = 17, int minute = 30}) =>
    NextPrayer(prayer: p, startsAt: DateTime(2026, 10, 28, hour, minute));

/// An open prayer the way the server describes it: [sent] groups have the
/// photo, [unsent] can still get one, and [canSend] says whether to offer the
/// camera.
CurrentPrayer _open(
  PrayerName p, {
  required bool logged,
  List<String> sent = const [],
  List<String> unsent = const ['g1'],
  bool? canSend,
}) => CurrentPrayer(
  prayer: p,
  date: '2026-10-28',
  startsAt: DateTime(2026, 10, 28, 15),
  endsAt: DateTime(2026, 10, 28, 17),
  logged: logged,
  logId: logged ? 'l1' : null,
  sentGroupIds: sent,
  unsentGroupIds: unsent,
  canSend: canSend ?? unsent.isNotEmpty,
);

/// Sent to every group.
CurrentPrayer _allSent(PrayerName p) =>
    _open(p, logged: true, sent: ['g1', 'g2'], unsent: const []);

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

    test('logged but some groups still have none: still available', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(
            PrayerName.asr,
            logged: true,
            sent: ['g1'],
            unsent: ['g2'],
          ),
        ),
      );
      expect(a.isAvailable, isTrue);
    });

    test('sent to every group: not available', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _allSent(PrayerName.asr),
          next: _next(PrayerName.maghrib),
        ),
      );
      expect(a.isAvailable, isFalse);
      expect(a.reason, SnapUnavailableReason.allGroupsSent);
      expect(a.loggedPrayer, PrayerName.asr);
      expect(a.next?.prayer, PrayerName.maghrib);
    });

    test('only groups with nobody else in them: not available', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(PrayerName.asr, logged: false, unsent: const []),
        ),
      );
      expect(a.reason, SnapUnavailableReason.noOtherMembers);
    });

    test('the log Special days made: not available', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(
            PrayerName.asr,
            logged: true,
            unsent: const [],
            canSend: false,
          ),
        ),
      );
      expect(a.reason, SnapUnavailableReason.specialDays);
    });

    test('Special days on, in the minute before the server logs it', () {
      final a = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(PrayerName.asr, logged: false, canSend: true),
        ),
        specialDays: true,
      );
      expect(a.reason, SnapUnavailableReason.specialDays);
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

    test('sent to all groups: names the prayer and when the next opens', () {
      final m = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _allSent(PrayerName.dhuhr),
          next: _next(PrayerName.asr, hour: 15, minute: 45),
        ),
      ).message!;
      expect(m, contains('You’ve sent your Dhuhr snap to all your groups.'));
      expect(m, contains('Asr starts at 3:45 PM.'));
    });

    test(
      'sent to all, with no next prayer known, still reads as a sentence',
      () {
        final m = SnapAvailability.fromPrayer(
          CurrentPrayerState(now: now, current: _allSent(PrayerName.isha)),
        ).message!;
        expect(m, contains('Isha snap'));
        expect(m, isNot(contains('starts at')));
        expect(m.trim(), endsWith('.'));
      },
    );

    test('nobody else in any group: says to invite someone', () {
      final m = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(PrayerName.asr, logged: false, unsent: const []),
        ),
      ).message!;
      expect(m, contains('anyone else'));
      expect(m, contains('Invite someone'));
    });

    test('Special days: says the prayer is logged for her', () {
      final m = SnapAvailability.fromPrayer(
        CurrentPrayerState(
          now: now,
          current: _open(PrayerName.asr, logged: false),
        ),
        specialDays: true,
      ).message!;
      expect(m, contains('Special days are on'));
      expect(m, contains('Asr'));
    });

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
          SnapUnavailableReason.allGroupsSent => SnapAvailability.fromPrayer(
            CurrentPrayerState(now: now, current: _allSent(PrayerName.asr)),
          ),
          SnapUnavailableReason.noOtherMembers => SnapAvailability.fromPrayer(
            CurrentPrayerState(
              now: now,
              current: _open(PrayerName.asr, logged: false, unsent: const []),
            ),
          ),
          SnapUnavailableReason.specialDays => SnapAvailability.fromPrayer(
            CurrentPrayerState(
              now: now,
              current: _open(PrayerName.asr, logged: false),
            ),
            specialDays: true,
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
          CurrentPrayerState(now: now, current: _allSent(PrayerName.asr)),
        ),
      );
      await c.read(currentPrayerProvider.future);
      expect(
        c.read(snapAvailabilityProvider).reason,
        SnapUnavailableReason.allGroupsSent,
      );
    });

    test(
      'Special days on: no camera, even before the server logs it',
      () async {
        final c = ProviderContainer(
          overrides: [
            currentPrayerProvider.overrideWith(
              () => FixedCurrent(
                CurrentPrayerState(
                  now: now,
                  current: _open(PrayerName.asr, logged: false),
                ),
              ),
            ),
            specialDaysProvider.overrideWith(_SpecialDaysOn.new),
          ],
        );
        addTearDown(c.dispose);
        await c.read(currentPrayerProvider.future);
        await c.read(specialDaysProvider.future);
        expect(
          c.read(snapAvailabilityProvider).reason,
          SnapUnavailableReason.specialDays,
        );
      },
    );

    test('the groups still open come from unsentGroupIds', () async {
      final c = make(
        () => FixedCurrent(
          CurrentPrayerState(
            now: now,
            current: _open(
              PrayerName.asr,
              logged: true,
              sent: ['g1'],
              unsent: ['g2', 'g3'],
            ),
          ),
        ),
      );
      await c.read(currentPrayerProvider.future);
      expect(c.read(snapSendableGroupIdsProvider), {'g2', 'g3'});
      expect(c.read(snapSentGroupIdsProvider), {'g1'});
    });

    test('no prayer open, or no answer yet: every group is offered', () async {
      final c = make(() => FixedCurrent(CurrentPrayerState(now: now)));
      await c.read(currentPrayerProvider.future);
      expect(c.read(snapSendableGroupIdsProvider), isNull);
      expect(c.read(snapSentGroupIdsProvider), isEmpty);
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

class _SpecialDaysOn extends SpecialDaysNotifier {
  @override
  Future<SpecialDays> build() async =>
      const SpecialDays(eligible: true, active: true);
}

class _NeverLoads extends CurrentPrayerNotifier {
  @override
  Future<CurrentPrayerState> build() => Completer<CurrentPrayerState>().future;
}

class _Fails extends CurrentPrayerNotifier {
  @override
  Future<CurrentPrayerState> build() async => throw Exception('offline');
}
