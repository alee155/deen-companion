// ignore_for_file: depend_on_referenced_packages
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/features/home/presentation/providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';

import '../../../helpers/in_memory_storage_service.dart';

class FakeLocationService implements LocationService {
  Coordinates? coordinates;
  LocationErrorKind? error;

  @override
  Future<Coordinates> getCurrentCoordinates({
    bool requestPermission = true,
  }) async {
    if (error != null) throw LocationServiceException(error!);
    return coordinates!;
  }

  @override
  Coordinates? lastStoredCoordinates() => null;
  @override
  Future<LocationAvailability> checkAvailability() async =>
      throw UnimplementedError();
  @override
  Future<LocationAvailability> requestPermission() async =>
      throw UnimplementedError();
  @override
  Future<void> openLocationSettings() async {}
  @override
  Future<void> openAppSettings() async {}
  @override
  Stream<void> serviceStatusChanges() => const Stream.empty();
}

class StaticRecovery extends LocationRecoveryNotifier {
  @override
  int build() => 0;
}

class FakeGeocoding extends GeocodingPlatform {
  List<Placemark>? result;
  Object? throwError;
  Duration delay = Duration.zero;
  double? lastLat;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    String? localeIdentifier,
  }) async {
    lastLat = latitude;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (throwError != null) throw throwError!;
    return result ?? const [];
  }
}

void main() {
  group('currentLocationNameProvider', () {
    const box = AppConstants.settingsBoxName;
    const cacheKey = 'last_known_location_name';
    late InMemoryStorageService storage;
    late FakeLocationService location;
    late FakeGeocoding geocoding;
    late ProviderContainer container;

    setUp(() {
      storage = InMemoryStorageService();
      location = FakeLocationService()
        ..coordinates = const Coordinates(
          latitude: 24.8607,
          longitude: 67.0011,
        );
      geocoding = FakeGeocoding();
      GeocodingPlatform.instance = geocoding;
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          locationServiceProvider.overrideWithValue(location),
          locationRecoveryProvider.overrideWith(StaticRecovery.new),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<LocationLabel> label() =>
        container.read(currentLocationNameProvider.future);

    test('city + country, and caches the name', () async {
      geocoding.result = const [
        Placemark(locality: 'Karachi', country: 'Pakistan'),
      ];
      final l = await label() as LocationLabelResolved;
      expect(l.name, 'Karachi, Pakistan');
      expect(l.isApproximate, isFalse);
      expect(storage.get<String>(box, cacheKey), 'Karachi, Pakistan');
    });

    test('stale coordinates produce an approximate label', () async {
      location.coordinates = const Coordinates(
        latitude: 1,
        longitude: 2,
        isStale: true,
      );
      geocoding.result = const [Placemark(locality: 'Lahore', country: 'PK')];
      final l = await label() as LocationLabelResolved;
      expect(l.isApproximate, isTrue);
    });

    test(
      'falls back to subAdministrativeArea when locality is empty',
      () async {
        geocoding.result = const [
          Placemark(
            locality: '',
            subAdministrativeArea: 'Gulshan',
            country: 'Pakistan',
          ),
        ];
        expect(
          (await label() as LocationLabelResolved).name,
          'Gulshan, Pakistan',
        );
      },
    );

    test('country only / city only', () async {
      geocoding.result = const [Placemark(locality: '', country: 'Pakistan')];
      expect((await label() as LocationLabelResolved).name, 'Pakistan');
      container.invalidate(currentLocationNameProvider);
      geocoding.result = const [Placemark(locality: 'Doha', country: '')];
      expect((await label() as LocationLabelResolved).name, 'Doha');
    });

    test('placemark with no usable fields falls back to coordinates', () async {
      geocoding.result = const [Placemark(locality: '', country: '')];
      final l = await label() as LocationLabelResolved;
      expect(l.name, '24.86, 67.00');
      expect(l.isApproximate, isTrue);
      expect(storage.get<String>(box, cacheKey), isNull);
    });

    test('geocoder returning nothing falls back to coordinates', () async {
      geocoding.result = const [];
      expect((await label() as LocationLabelResolved).name, '24.86, 67.00');
    });

    test(
      'geocoder failure falls back to the cached name when present',
      () async {
        await storage.put(box, cacheKey, 'Islamabad, Pakistan');
        geocoding.throwError = Exception('no play services');
        final l = await label() as LocationLabelResolved;
        expect(l.name, 'Islamabad, Pakistan');
        expect(l.isApproximate, isTrue);
      },
    );

    test('geocoder failure without cache falls back to coordinates', () async {
      geocoding.throwError = Exception('boom');
      expect((await label() as LocationLabelResolved).name, '24.86, 67.00');
    });

    test('location failure uses cached name as approximate', () async {
      await storage.put(box, cacheKey, 'Dubai, UAE');
      location.error = LocationErrorKind.serviceDisabled;
      final l = await label() as LocationLabelResolved;
      expect(l.name, 'Dubai, UAE');
      expect(l.isApproximate, isTrue);
    });

    test('location failure without cache surfaces the error kind', () async {
      location.error = LocationErrorKind.permissionDeniedForever;
      final l = await label() as LocationLabelUnavailable;
      expect(l.kind, LocationErrorKind.permissionDeniedForever);
    });

    test('empty cached name is ignored on location failure', () async {
      await storage.put(box, cacheKey, '');
      location.error = LocationErrorKind.timeout;
      expect(await label(), isA<LocationLabelUnavailable>());
    });
  });
}
