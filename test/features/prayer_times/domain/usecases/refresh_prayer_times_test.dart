import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/domain/prayer_times_failure.dart';
import 'package:deen_companion/features/prayer_times/domain/usecases/refresh_prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';

// Lahore, and a point ~20 km away (still "not moved", < 10 km is the rule, so
// this one counts as a real move).
const _lahore = Coordinates(latitude: 31.5204, longitude: 74.3587);
const _nearby = Coordinates(latitude: 31.5, longitude: 74.35); // ~2 km
const _karachi = Coordinates(latitude: 24.8607, longitude: 67.0011);

const _savedLahore = SavedPrayerSettings(
  location: PrayerLocation(
    latitude: 31.52,
    longitude: 74.36,
    timezone: 'Asia/Karachi',
  ),
  method: CalculationMethodInfo(
    id: 3,
    name: 'MWL',
    school: 'standard',
    schoolId: 0,
  ),
);

void main() {
  late FakePrayerRepo repo;
  late RefreshPrayerTimes refresh;

  setUp(() {
    repo = FakePrayerRepo();
    refresh = RefreshPrayerTimes(repo);
    final b = bundleOf([pt(14)]);
    repo
      ..guestResult = Success(b)
      ..putResult = Success(b)
      ..accountResult = Success(b);
  });

  RefreshPrayerTimesParams params({
    bool signedIn = false,
    Coordinates at = _lahore,
    String? country,
    int? method,
    int? school,
    bool changed = false,
  }) => RefreshPrayerTimesParams(
    isSignedIn: signedIn,
    coordinates: at,
    countryCode: country,
    chosenMethod: method,
    chosenSchool: school,
    settingsChanged: changed,
  );

  RefreshPrayerTimesResult ok(Result<RefreshPrayerTimesResult> r) =>
      (r as Success<RefreshPrayerTimesResult>).data;

  group('guest', () {
    test('Pakistan: sends no method or school', () async {
      await refresh(params(country: 'PK'));
      expect(repo.calls, ['guestTimes']);
      expect(repo.lastSent, (method: null, school: null));
    });

    test('unknown country: sends nothing either', () async {
      await refresh(params());
      expect(repo.lastSent, (method: null, school: null));
    });

    test('outside Pakistan: sends MWL and Shafi', () async {
      await refresh(params(country: 'AE'));
      expect(repo.lastSent, (method: 3, school: 0));
    });

    test('a chosen method and school are sent as chosen', () async {
      await refresh(params(country: 'PK', method: 5, school: 1));
      expect(repo.lastSent, (method: 5, school: 1));
    });

    test(
      'adopts the server settings and reports the change as applied',
      () async {
        final r = ok(await refresh(params(changed: true)));
        expect(r.adoptSettings, isTrue);
        expect(r.settingsApplied, isTrue);
      },
    );

    test('unverified fallback times are not adopted as settings', () async {
      repo.guestResult = Success(bundleOf([pt(14)], unverified: true));
      final r = ok(await refresh(params()));
      expect(r.adoptSettings, isFalse);
      expect(r.settingsApplied, isFalse);
    });

    test('a failure is passed on', () async {
      repo.guestResult = const Error(NetworkFailure());
      expect((await refresh(params()) as Error).failure, isA<NetworkFailure>());
    });
  });

  group('signed in, first time on this account', () {
    test(
      'Pakistan: PUT with no method or school, then reads 31 days',
      () async {
        await refresh(params(signedIn: true, country: 'PK'));
        expect(repo.calls, ['getSaved', 'put', 'accountTimes']);
        expect(repo.lastSent, (method: null, school: null));
      },
    );

    test('outside Pakistan: PUT carries MWL and Shafi', () async {
      await refresh(params(signedIn: true, country: 'GB'));
      expect(repo.lastSent, (method: 3, school: 0));
    });

    test('a guest\'s choices carry over to the new account', () async {
      await refresh(
        params(signedIn: true, country: 'PK', method: 5, school: 0),
      );
      expect(repo.lastSent, (method: 5, school: 0));
    });

    test('the result says the settings reached the server', () async {
      final r = ok(await refresh(params(signedIn: true)));
      expect(r.settingsApplied, isTrue);
      expect(r.adoptSettings, isTrue);
    });
  });

  group('signed in, saved location', () {
    setUp(() => repo.savedResult = const Success(_savedLahore));

    test('same place: no PUT, the account\'s choice is adopted', () async {
      final r = ok(await refresh(params(signedIn: true, at: _lahore)));
      expect(repo.calls, ['getSaved', 'accountTimes']);
      expect(r.adoptSettings, isTrue);
      expect(r.settingsApplied, isFalse);
    });

    test('a few km away is not a move', () async {
      await refresh(params(signedIn: true, at: _nearby));
      expect(repo.calls, isNot(contains('put')));
    });

    test('a real move (over 10 km) sends the new place only', () async {
      await refresh(params(signedIn: true, at: _karachi, country: 'PK'));
      expect(repo.calls, ['getSaved', 'put', 'accountTimes']);
      expect(repo.lastCoordinates!.latitude, _karachi.latitude);
      expect(repo.lastSent, (
        method: null,
        school: null,
      ), reason: 'the server keeps the saved method and school');
    });

    test(
      'a new phone with different local choices does not overwrite the account',
      () async {
        // Local values exist (an old guest choice) but nothing was changed now.
        await refresh(params(signedIn: true, method: 5, school: 1));
        expect(repo.calls, ['getSaved', 'accountTimes']);
      },
    );

    test('a user change resends the SAME place with both values', () async {
      await refresh(
        params(signedIn: true, at: _karachi, method: 5, changed: true),
      );
      expect(repo.calls, ['getSaved', 'put', 'accountTimes']);
      // The saved place (Lahore), not where the phone is now.
      expect(repo.lastCoordinates!.latitude, closeTo(31.52, 1e-9));
      // Chose only a method: the school stays what the account had (0).
      expect(repo.lastSent, (method: 5, school: 0));
    });

    test('a change of school keeps the saved method', () async {
      await refresh(params(signedIn: true, school: 1, changed: true));
      expect(repo.lastSent, (method: 3, school: 1));
    });

    test('locked days from the PUT reach the result', () async {
      repo.putResult = Success(bundleOf([pt(14)], lockedDates: ['2026-10-14']));
      final r = ok(
        await refresh(params(signedIn: true, method: 5, changed: true)),
      );
      expect(r.bundle.lockedDates, ['2026-10-14']);
      expect(r.settingsApplied, isTrue);
    });

    test('no locked days without a PUT', () async {
      final r = ok(await refresh(params(signedIn: true)));
      expect(r.bundle.lockedDates, isEmpty);
    });

    test('a failed PUT stops before reading times', () async {
      repo.putResult = const Error(NetworkFailure());
      final r = await refresh(params(signedIn: true, method: 5, changed: true));
      expect(r, isA<Error>());
      expect(repo.calls, ['getSaved', 'put']);
    });
  });

  group('signed in, edge cases', () {
    test(
      'the account lost its location: sets it again and retries once',
      () async {
        repo.savedResult = const Success(_savedLahore);
        var calls = 0;
        // First read says no location; after the PUT it works.
        repo.accountResult = const Error(
          PrayerTimesFailure(
            'Set your location first',
            code: PrayerTimesErrorCode.locationNotSet,
            statusCode: 409,
          ),
        );
        final first = refresh(params(signedIn: true, country: 'PK'));
        final r = await first;
        calls = repo.calls.where((c) => c == 'accountTimes').length;
        expect(
          r,
          isA<Error>(),
          reason: 'the retry also hits LOCATION_NOT_SET here',
        );
        expect(calls, 2, reason: 'one read, one retry — never a loop');
        expect(repo.calls, contains('put'));
      },
    );

    test(
      'cannot read saved settings with no cache: falls back to the guest path',
      () async {
        repo.savedResult = const Error(NetworkFailure());
        repo.guestResult = Success(bundleOf([pt(14)], unverified: true));
        final r = ok(await refresh(params(signedIn: true, country: 'PK')));
        expect(repo.calls, ['getSaved', 'guestTimes']);
        expect(r.bundle.isUnverified, isTrue);
      },
    );

    test(
      'cannot read saved settings but a cache exists: keeps the cache (error)',
      () async {
        repo.bundle = bundleOf([pt(14)]);
        repo.savedResult = const Error(NetworkFailure());
        final r = await refresh(params(signedIn: true));
        expect(r, isA<Error>());
        expect(repo.calls, ['getSaved']);
      },
    );

    test(
      'a request error (not unreachable) does not trigger the guest fallback',
      () async {
        repo.savedResult = const Error(
          PrayerTimesFailure('bad', statusCode: 400),
        );
        final r = await refresh(params(signedIn: true));
        expect(r, isA<Error>());
        expect(repo.calls, ['getSaved']);
      },
    );

    test('a 5xx with no cache falls back like a network error', () async {
      repo.savedResult = const Error(
        PrayerTimesFailure('down', statusCode: 503),
      );
      repo.guestResult = Success(bundleOf([pt(14)], unverified: true));
      ok(await refresh(params(signedIn: true)));
      expect(repo.calls, ['getSaved', 'guestTimes']);
    });
  });
}
