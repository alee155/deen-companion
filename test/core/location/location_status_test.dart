import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_storage.dart';

class _Svc implements LocationService {
  final calls = <String>[];
  LocationAvailability afterRequest;
  _Svc(this.afterRequest);
  @override
  Future<void> openAppSettings() async => calls.add('appSettings');
  @override
  Future<void> openLocationSettings() async => calls.add('locSettings');
  @override
  Future<LocationAvailability> requestPermission() async {
    calls.add('request');
    return afterRequest;
  }

  @override
  Future<LocationAvailability> checkAvailability() =>
      throw UnimplementedError();
  @override
  Future<Coordinates> getCurrentCoordinates({bool requestPermission = true}) =>
      throw UnimplementedError();
  @override
  Coordinates? lastStoredCoordinates() => null;
  @override
  Stream<void> serviceStatusChanges() => const Stream.empty();
}

LocationAvailability _a(bool service, bool perm, bool forever) =>
    LocationAvailability(
      serviceEnabled: service,
      hasPermission: perm,
      permanentlyDenied: forever,
    );

void main() {
  group('LocationAvailability', () {
    test('usable only when service on and permission granted', () {
      expect(_a(true, true, false).isUsable, isTrue);
      expect(_a(false, true, false).isUsable, isFalse);
      expect(_a(true, false, false).isUsable, isFalse);
    });

    test('errorKind priority: service > forever > denied > none', () {
      expect(
        _a(false, false, true).errorKind,
        LocationErrorKind.serviceDisabled,
      );
      expect(
        _a(true, false, true).errorKind,
        LocationErrorKind.permissionDeniedForever,
      );
      expect(
        _a(true, false, false).errorKind,
        LocationErrorKind.permissionDenied,
      );
      expect(_a(true, true, false).errorKind, isNull);
    });
  });

  group('LocationErrorKindX', () {
    test('requestable only for permissionDenied', () {
      for (final k in LocationErrorKind.values) {
        expect(k.isRequestable, k == LocationErrorKind.permissionDenied);
      }
    });

    test('needsSystemSettings', () {
      expect(LocationErrorKind.serviceDisabled.needsSystemSettings, isTrue);
      expect(
        LocationErrorKind.permissionDeniedForever.needsSystemSettings,
        isTrue,
      );
      expect(LocationErrorKind.permissionDenied.needsSystemSettings, isFalse);
      expect(LocationErrorKind.timeout.needsSystemSettings, isFalse);
      expect(LocationErrorKind.unavailable.needsSystemSettings, isFalse);
    });

    test('every kind has a message and action label', () {
      for (final k in LocationErrorKind.values) {
        expect(k.userMessage, isNotEmpty);
        expect(k.actionLabel, isNotEmpty);
      }
    });
  });

  test('LocationServiceException defaults message from kind', () {
    final e = LocationServiceException(LocationErrorKind.timeout);
    expect(e.message, LocationErrorKind.timeout.userMessage);
    expect(e.toString(), e.message);
    expect(
      LocationServiceException(LocationErrorKind.timeout, 'm').message,
      'm',
    );
  });

  group('resolveLocationIssue', () {
    test('serviceDisabled opens location settings', () async {
      final s = _Svc(_a(true, true, false));
      await resolveLocationIssue(s, LocationErrorKind.serviceDisabled);
      expect(s.calls, ['locSettings']);
    });

    test('permissionDeniedForever opens app settings', () async {
      final s = _Svc(_a(true, true, false));
      await resolveLocationIssue(s, LocationErrorKind.permissionDeniedForever);
      expect(s.calls, ['appSettings']);
    });

    test('permissionDenied requests; granted -> no settings', () async {
      final s = _Svc(_a(true, true, false));
      await resolveLocationIssue(s, LocationErrorKind.permissionDenied);
      expect(s.calls, ['request']);
    });

    test(
      'permissionDenied escalates to app settings if now permanent',
      () async {
        final s = _Svc(_a(true, false, true));
        await resolveLocationIssue(s, LocationErrorKind.permissionDenied);
        expect(s.calls, ['request', 'appSettings']);
      },
    );

    test('timeout / unavailable do nothing', () async {
      final s = _Svc(_a(true, true, false));
      await resolveLocationIssue(s, LocationErrorKind.timeout);
      await resolveLocationIssue(s, LocationErrorKind.unavailable);
      expect(s.calls, isEmpty);
    });
  });

  group('GeolocatorLocationService.lastStoredCoordinates', () {
    test('null when nothing stored or only one half stored', () {
      final st = FakeStorage();
      final s = GeolocatorLocationService(st);
      expect(s.lastStoredCoordinates(), isNull);
      st.boxes[AppConstants.settingsBoxName] = {'last_known_latitude': 1.0};
      expect(s.lastStoredCoordinates(), isNull);
    });

    test('returns stale coordinates when both stored', () {
      final st = FakeStorage();
      st.boxes[AppConstants.settingsBoxName] = {
        'last_known_latitude': 31.5,
        'last_known_longitude': 74.3,
      };
      final c = GeolocatorLocationService(st).lastStoredCoordinates()!;
      expect(c.latitude, 31.5);
      expect(c.longitude, 74.3);
      expect(c.isStale, isTrue);
    });
  });
}
