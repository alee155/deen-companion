// ignore_for_file: depend_on_referenced_packages
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/home/presentation/providers/home_provider.dart';
import 'package:deen_companion/features/home/presentation/providers/home_recitations_provider.dart';
import 'package:deen_companion/features/quran/domain/entities/surah_summary.dart';
import 'package:deen_companion/features/quran/presentation/providers/quran_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';

import '../../../helpers/in_memory_storage_service.dart';

SurahSummary surah(int n) => SurahSummary(
  number: n,
  nameArabic: 'ar$n',
  nameEnglish: 'S$n',
  nameTranslation: 't$n',
  revelationPlace: 'Mecca',
  versesCount: n,
  bismillahPre: true,
  exampleAudioUrl: 'u$n',
);

class FakeSurahList extends SurahListNotifier {
  final List<SurahSummary>? cached;
  final Result<List<SurahSummary>> fresh;
  FakeSurahList(this.cached, this.fresh);

  @override
  List<SurahSummary>? readCache() => cached;

  @override
  Future<Result<List<SurahSummary>>> fetchFresh() async => fresh;
}

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
  group('featuredRecitationsProvider', () {
    ProviderContainer make(
      List<SurahSummary>? cached,
      Result<List<SurahSummary>> fresh,
    ) {
      final c = ProviderContainer(
        overrides: [
          surahListNotifierProvider.overrideWith(
            () => FakeSurahList(cached, fresh),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('featured numbers are the curated set', () {
      expect(featuredSurahNumbers, [1, 2, 36, 55, 67]);
    });

    test('selects featured surahs in curated order, not list order', () async {
      final all = [for (var i = 114; i >= 1; i--) surah(i)];
      final c = make(all, Success(all));
      await c.read(surahListNotifierProvider.future);
      final featured = c.read(featuredRecitationsProvider).requireValue;
      expect(featured.map((s) => s.number), [1, 2, 36, 55, 67]);
    });

    test('silently skips featured surahs missing from the list', () async {
      final partial = [surah(2), surah(67), surah(3)];
      final c = make(partial, Success(partial));
      await c.read(surahListNotifierProvider.future);
      expect(
        c.read(featuredRecitationsProvider).requireValue.map((s) => s.number),
        [2, 67],
      );
    });

    test('empty list yields empty featured list', () async {
      final c = make(const [], const Success(<SurahSummary>[]));
      await c.read(surahListNotifierProvider.future);
      expect(c.read(featuredRecitationsProvider).requireValue, isEmpty);
    });

    test('loading state is propagated', () {
      final c = make(null, const Success(<SurahSummary>[]));
      expect(c.read(featuredRecitationsProvider).isLoading, isTrue);
    });

    test('error state is propagated when nothing cached', () async {
      final c = make(null, const Error(NetworkFailure()));
      await expectLater(
        c.read(surahListNotifierProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(c.read(featuredRecitationsProvider).hasError, isTrue);
    });
  });

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
