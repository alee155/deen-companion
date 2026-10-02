
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/qibla/data/datasources/qibla_native_channel.dart';
import 'package:deen_companion/features/qibla/domain/entities/qibla_info.dart';
import 'package:deen_companion/features/qibla/domain/repositories/qibla_repository.dart';
import 'package:deen_companion/features/qibla/presentation/providers/qibla_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';

const _info = QiblaInfo(
  qiblaDirection: 118,
  compassBearing: 'ESE',
  distanceKm: 4000,
  distanceMiles: 2485,
  note: 'n',
  latitude: 51.5,
  longitude: -0.12,
);

class _Repo implements QiblaRepository {
  Result<QiblaInfo> result = const Success(_info);
  int calls = 0;
  @override
  Future<Result<QiblaInfo>> getQiblaForCurrentLocation({
    bool forceRefresh = false,
  }) async {
    calls++;
    return result;
  }
}

class _NoRecovery extends LocationRecoveryNotifier {
  @override
  int build() => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const qiblaChannel = MethodChannel('com.devsouq.deen_companion.app/qibla');

  setUpAll(initFlavorForTests);
  tearDown(() => messenger.setMockMethodCallHandler(qiblaChannel, null));

  late _Repo repo;
  ProviderContainer make() {
    repo = _Repo();
    final c = ProviderContainer(
      overrides: [
        qiblaRepositoryProvider.overrideWithValue(repo),
        locationRecoveryProvider.overrideWith(_NoRecovery.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('QiblaNotifier', () {
    test('success exposes QiblaInfo', () async {
      final c = make();
      expect(await c.read(qiblaNotifierProvider.future), _info);
    });

    test('failure is thrown as the Failure object', () async {
      final c = make();
      repo.result = const Error(NetworkFailure());
      await expectLater(
        c.read(qiblaNotifierProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('refresh re-queries the repository', () async {
      final c = make();
      final sub = c.listen(qiblaNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(qiblaNotifierProvider.future);
      await c.read(qiblaNotifierProvider.notifier).refresh();
      expect(repo.calls, 2);
    });
  });

  group('QiblaNativeChannel / magneticDeclinationProvider', () {
    test('passes coordinates to native and returns declination', () async {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(qiblaChannel, (c) async {
        seen = c;
        return -1.25;
      });
      final d = await QiblaNativeChannel.getMagneticDeclination(
        latitude: 51.5,
        longitude: -0.12,
      );
      expect(d, -1.25);
      expect(seen!.method, 'getMagneticDeclination');
      expect(seen!.arguments, {'latitude': 51.5, 'longitude': -0.12});
    });

    test('missing platform implementation (iOS) -> null', () async {
      expect(
        await QiblaNativeChannel.getMagneticDeclination(
          latitude: 0,
          longitude: 0,
        ),
        isNull,
      );
    });

    test('native error -> null, never throws', () async {
      messenger.setMockMethodCallHandler(
        qiblaChannel,
        (c) async => throw PlatformException(code: 'x'),
      );
      expect(
        await QiblaNativeChannel.getMagneticDeclination(
          latitude: 0,
          longitude: 0,
        ),
        isNull,
      );
    });

    test('provider uses the Qibla result coordinates', () async {
      Object? args;
      messenger.setMockMethodCallHandler(qiblaChannel, (c) async {
        args = c.arguments;
        return 3.5;
      });
      final c = make();
      expect(await c.read(magneticDeclinationProvider.future), 3.5);
      expect(args, {'latitude': 51.5, 'longitude': -0.12});
    });

    test('provider falls back to 0.0 when native has no answer', () async {
      final c = make();
      expect(await c.read(magneticDeclinationProvider.future), 0.0);
    });
  });

  group('compassHeadingProvider', () {
    const eventChannel = EventChannel('hemanthraj/flutter_compass');

    // NOTE: Riverpod 2.x subscribes twice to a broadcast StreamProvider
    // source, so the provider's shared closure state sees each platform event
    // twice. These tests therefore assert robust properties (wrap-around,
    // lag, null accuracy, range) rather than exact smoothed numbers.
    Future<List<CompassReading>> run(List<List<double>> events) async {
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (args, sink) {
            for (final e in events) {
              sink.success(e);
            }
          },
        ),
      );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final out = <CompassReading>[];
      final sub = c.listen(compassHeadingProvider, (_, n) {
        if (n.hasValue) out.add(n.value!);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return out;
    }

    double circDist(double a, double b) {
      final d = (a - b).abs() % 360;
      return d > 180 ? 360 - d : d;
    }

    test('sensor accuracy of -1 is reported as null (unknown)', () async {
      final r = await run([
        for (var h = 10.0; h < 200; h += 30) [h, 0.0, -1.0],
      ]);
      expect(r, isNotEmpty);
      expect(r.every((e) => e.accuracy == null), isTrue);
    });

    test('real accuracy values pass through untouched', () async {
      final r = await run([
        for (var h = 10.0; h < 200; h += 30) [h, 0.0, 15.0],
      ]);
      expect(r, isNotEmpty);
      expect(r.every((e) => e.accuracy == 15.0), isTrue);
    });

    test('smoothing lags a sudden jump instead of snapping to it', () async {
      final r = await run([
        [0.0, 0.0, 10.0],
        [90.0, 0.0, 10.0],
      ]);
      expect(r, isNotEmpty);
      for (final e in r) {
        expect(e.heading!, lessThan(90));
      }
    });

    test('crossing north clockwise never swings through the south', () async {
      final r = await run([
        [350.0, 0.0, 10.0],
        [10.0, 0.0, 10.0],
        [10.0, 0.0, 10.0],
      ]);
      expect(r, isNotEmpty);
      for (final e in r) {
        // stays within 20 degrees of north, i.e. took the short way.
        expect(circDist(e.heading!, 0), lessThanOrEqualTo(20));
        expect(e.heading!, inInclusiveRange(0, 360));
      }
    });

    test('crossing north counter-clockwise also takes the short way', () async {
      final r = await run([
        [10.0, 0.0, 10.0],
        [350.0, 0.0, 10.0],
        [350.0, 0.0, 10.0],
      ]);
      expect(r, isNotEmpty);
      for (final e in r) {
        expect(circDist(e.heading!, 0), lessThanOrEqualTo(20));
      }
    });

    test('headings are always normalised into [0, 360)', () async {
      final r = await run([
        for (final h in [355.0, 5.0, 355.0, 5.0, 359.0, 1.0]) [h, 0.0, 10.0],
      ]);
      expect(r, isNotEmpty);
      for (final e in r) {
        expect(e.heading!, greaterThanOrEqualTo(0));
        expect(e.heading!, lessThan(360));
      }
    });
  });
}
