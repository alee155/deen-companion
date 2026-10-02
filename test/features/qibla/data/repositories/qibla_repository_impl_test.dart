import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/qibla/data/datasources/qibla_remote_datasource.dart';
import 'package:deen_companion/features/qibla/data/models/qibla_info_model.dart';
import 'package:deen_companion/features/qibla/data/repositories/qibla_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockRemote extends Mock implements QiblaRemoteDataSource {}

QiblaInfoModel _model([double dir = 118.0]) => QiblaInfoModel(
  qiblaDirection: dir,
  compassBearing: 'ESE',
  distanceKm: 4000,
  distanceMiles: 2485,
  note: 'n',
);

void main() {
  late _MockRemote remote;
  late PaLocation location;
  late PaStorage storage;
  late PaNetwork network;
  late QiblaRepositoryImpl repo;

  setUpAll(initFlavorForTests);
  setUp(() {
    remote = _MockRemote();
    location = PaLocation()
      ..coordinates = const Coordinates(latitude: 51.5074, longitude: -0.1278);
    storage = PaStorage();
    network = PaNetwork();
    repo = QiblaRepositoryImpl(
      remoteDataSource: remote,
      locationService: location,
      cacheStore: storage.cache,
      networkInfo: network,
    );
  });

  // 51.5074, -0.1278 -> rounded to 2dp
  const key = 'qibla_51.51_-0.13';

  Map<String, dynamic> seedJson([double dir = 100]) =>
      _model(dir).withCoordinates(51.5074, -0.1278).toJson();

  void stubRemote([QiblaInfoModel? m]) => when(
    () => remote.getQibla(any(), any()),
  ).thenAnswer((_) async => m ?? _model());

  test('fresh fetch attaches the requested coordinates and caches', () async {
    stubRemote();
    final r = await repo.getQiblaForCurrentLocation();
    final info = (r as Success).data;
    expect(info.qiblaDirection, 118.0);
    expect(info.latitude, 51.5074);
    expect(info.longitude, -0.1278);
    expect(storage.hasCached(key), isTrue);
    verify(() => remote.getQibla(51.5074, -0.1278)).called(1);
  });

  test(
    'cache key rounds to 2 decimals so nearby fixes share an entry',
    () async {
      stubRemote();
      await repo.getQiblaForCurrentLocation();
      location.coordinates = const Coordinates(
        latitude: 51.5051,
        longitude: -0.1251,
      );
      await repo.getQiblaForCurrentLocation();
      verify(() => remote.getQibla(any(), any())).called(1);
    },
  );

  test('a location >0.005 deg away misses the cache', () async {
    stubRemote();
    await repo.getQiblaForCurrentLocation();
    location.coordinates = const Coordinates(
      latitude: 51.52,
      longitude: -0.1278,
    );
    await repo.getQiblaForCurrentLocation();
    verify(() => remote.getQibla(any(), any())).called(2);
  });

  test('fresh cache is served without network', () async {
    storage.seed(key, seedJson(), age: const Duration(days: 6));
    final r = await repo.getQiblaForCurrentLocation();
    expect((r as Success).data.qiblaDirection, 100);
    verifyNever(() => remote.getQibla(any(), any()));
  });

  test('stale cache (>7d) triggers a refetch', () async {
    storage.seed(key, seedJson(), age: const Duration(days: 8));
    stubRemote(_model(118));
    final r = await repo.getQiblaForCurrentLocation();
    expect((r as Success).data.qiblaDirection, 118);
  });

  test('forceRefresh bypasses a fresh cache', () async {
    storage.seed(key, seedJson());
    stubRemote(_model(118));
    final r = await repo.getQiblaForCurrentLocation(forceRefresh: true);
    expect((r as Success).data.qiblaDirection, 118);
  });

  test('offline: stale cache is better than nothing', () async {
    storage.seed(key, seedJson(), age: const Duration(days: 30));
    network.connected = false;
    final r = await repo.getQiblaForCurrentLocation();
    expect((r as Success).data.qiblaDirection, 100);
    verifyNever(() => remote.getQibla(any(), any()));
  });

  test('offline without cache -> NetworkFailure', () async {
    network.connected = false;
    final r = await repo.getQiblaForCurrentLocation();
    expect((r as Error).failure, isA<NetworkFailure>());
  });

  test('ServerException with stale cache falls back to cache', () async {
    storage.seed(key, seedJson(), age: const Duration(days: 30));
    when(
      () => remote.getQibla(any(), any()),
    ).thenThrow(const ServerException('x'));
    final r = await repo.getQiblaForCurrentLocation();
    expect(r, isA<Success>());
  });

  test('ServerException without cache keeps the server message', () async {
    when(
      () => remote.getQibla(any(), any()),
    ).thenThrow(const ServerException('bad gateway'));
    final r = await repo.getQiblaForCurrentLocation();
    final f = (r as Error).failure;
    expect(f, isA<ServerFailure>());
    expect(f.message, 'bad gateway');
  });

  test('ServerException with null message uses the default text', () async {
    when(
      () => remote.getQibla(any(), any()),
    ).thenThrow(const ServerException());
    final f = ((await repo.getQiblaForCurrentLocation()) as Error).failure;
    expect(f.message, const ServerFailure().message);
  });

  test('malformed payload (TypeError) -> UnexpectedFailure', () async {
    when(() => remote.getQibla(any(), any())).thenThrow(TypeError());
    final f = ((await repo.getQiblaForCurrentLocation()) as Error).failure;
    expect(f, isA<UnexpectedFailure>());
  });

  test('location failure short-circuits with its kind and message', () async {
    location.error = locErr(LocationErrorKind.permissionDeniedForever);
    final f = ((await repo.getQiblaForCurrentLocation()) as Error).failure;
    expect(
      (f as LocationFailure).kind,
      LocationErrorKind.permissionDeniedForever,
    );
    expect(f.message, LocationErrorKind.permissionDeniedForever.userMessage);
    verifyNever(() => remote.getQibla(any(), any()));
  });

  test('legacy cache entry without coordinates still loads (0,0)', () async {
    final legacy = seedJson()
      ..remove('latitude')
      ..remove('longitude');
    storage.seed(key, legacy);
    final info = ((await repo.getQiblaForCurrentLocation()) as Success).data;
    expect(info.latitude, 0.0);
  });
}
