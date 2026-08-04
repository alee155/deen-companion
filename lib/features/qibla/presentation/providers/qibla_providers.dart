import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/qibla_native_channel.dart';
import '../../data/datasources/qibla_remote_datasource.dart';
import '../../data/repositories/qibla_repository_impl.dart';
import '../../domain/entities/qibla_info.dart';
import '../../domain/repositories/qibla_repository.dart';

final qiblaRemoteDataSourceProvider = Provider<QiblaRemoteDataSource>((ref) {
  return QiblaRemoteDataSourceImpl(ref.watch(dioProvider));
});

final qiblaRepositoryProvider = Provider<QiblaRepository>((ref) {
  return QiblaRepositoryImpl(
    remoteDataSource: ref.watch(qiblaRemoteDataSourceProvider),
    locationService: ref.watch(locationServiceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class QiblaNotifier extends AsyncNotifier<QiblaInfo> {
  @override
  Future<QiblaInfo> build() async {
    final result = await ref
        .watch(qiblaRepositoryProvider)
        .getQiblaForCurrentLocation();
    return result.when(success: (d) => d, failure: (f) => throw f);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final qiblaNotifierProvider = AsyncNotifierProvider<QiblaNotifier, QiblaInfo>(
  QiblaNotifier.new,
);

/// Real magnetic declination (degrees) for wherever the current Qibla
/// result was calculated — the correction needed to turn the device's
/// magnetic-north heading into a true-north heading.
///
/// This exists because of a real, confirmed mismatch: the Qibla bearing
/// from the API is degrees from *true* north, but flutter_compass's
/// `heading` is *magnetic* north on every platform (its maintainers
/// deliberately reverted an earlier true-heading attempt because it
/// "caused deviations" — so magnetic-only is the honest, current behavior
/// of the plugin, not a bug in it). Comparing a true bearing against a
/// magnetic heading with no correction is off by exactly this amount,
/// and that amount is location-dependent — it can be several degrees or
/// more depending on where in the world the phone is.
///
/// Defaults to 0.0 (i.e. behaves like before this fix existed) if the
/// coordinates aren't resolved yet or the native call fails for any
/// reason — never blocks the compass from showing *a* reading while this
/// resolves, which in practice is near-instant since it's a local
/// computation, not a network call.
final magneticDeclinationProvider = FutureProvider<double>((ref) async {
  final qibla = await ref.watch(qiblaNotifierProvider.future);
  final declination = await QiblaNativeChannel.getMagneticDeclination(
    latitude: qibla.latitude,
    longitude: qibla.longitude,
  );
  return declination ?? 0.0;
});

/// A single throttled, smoothed compass reading: the heading itself, plus
/// the sensor's own confidence in that heading (lower = more reliable;
/// null on devices/OS versions that don't report it at all).
class CompassReading {
  final double? heading;
  final double? accuracy;
  const CompassReading({required this.heading, required this.accuracy});
}

// Live device compass heading (magnetic north) plus sensor accuracy,
// smoothed and throttled — heading is null if unavailable (unsupported
// hardware) or not yet resolved.
//
// IMPORTANT: the raw platform stream fires very frequently (commonly
// 20–50+ events/sec depending on the device's sensor sampling rate).
// Piping every single event straight into a StreamProvider that the
// Qibla screen watches at the top of build() forced a full-screen
// widget rebuild on every tick. On lower-end hardware that easily
// blows the 16ms frame budget and is a classic cause of dropped
// frames turning into an "Application Not Responding" dialog. We
// throttle to at most ~8 emissions/sec and additionally skip events
// that haven't moved the heading meaningfully, so a stationary phone
// doesn't keep forcing rebuilds at all.
//
// We also exponentially smooth the heading itself. Raw magnetometer
// readings are visibly jittery on most phones — the needle would
// otherwise twitch a few degrees back and forth even when the phone is
// held still. A light exponential moving average (each new reading only
// nudges the displayed heading part-way towards it) removes that jitter
// without adding perceptible lag.
//
// Accuracy is passed through as-is (not smoothed) — it's a discrete
// quality signal from the sensor, not a continuous value to average.
final compassHeadingProvider = StreamProvider<CompassReading>((ref) {
  final events = FlutterCompass.events;
  if (events == null) {
    return Stream.value(const CompassReading(heading: null, accuracy: null));
  }

  double? lastEmittedHeading;
  double? smoothedHeading;
  DateTime lastEmittedAt = DateTime.fromMillisecondsSinceEpoch(0);

  return events
      .map((event) {
        final raw = event.heading;
        if (raw == null) {
          return CompassReading(heading: null, accuracy: event.accuracy);
        }

        if (smoothedHeading == null) {
          smoothedHeading = raw;
        } else {
          // Shortest angular distance, so smoothing doesn't spin the long
          // way round when crossing the 0°/360° boundary.
          double delta = (raw - smoothedHeading!) % 360;
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          const smoothingFactor = 0.35; // higher = more responsive, less smooth
          smoothedHeading = (smoothedHeading! + delta * smoothingFactor) % 360;
          if (smoothedHeading! < 0) smoothedHeading = smoothedHeading! + 360;
        }
        return CompassReading(
          heading: smoothedHeading,
          accuracy: event.accuracy,
        );
      })
      .where((reading) {
        final now = DateTime.now();
        final elapsedSinceLastEmit = now.difference(lastEmittedAt);
        final heading = reading.heading;

        final headingMovedEnough =
            lastEmittedHeading == null ||
            heading == null ||
            (heading - lastEmittedHeading!).abs() >= 0.5;

        if (elapsedSinceLastEmit < const Duration(milliseconds: 120) &&
            !headingMovedEnough) {
          return false;
        }

        lastEmittedHeading = heading;
        lastEmittedAt = now;
        return true;
      });
});
