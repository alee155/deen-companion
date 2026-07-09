import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
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

// Live device compass heading — degrees from magnetic north, null if
// unavailable (unsupported hardware) or not yet resolved.
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
final compassEventProvider = StreamProvider<CompassEvent?>((ref) {
  final events = FlutterCompass.events;
  if (events == null) return const Stream.empty();

  double? lastHeading;
  DateTime lastEmittedAt = DateTime.fromMillisecondsSinceEpoch(0);

  return events.where((event) {
    final now = DateTime.now();
    final heading = event.heading;
    final elapsedSinceLastEmit = now.difference(lastEmittedAt);

    final headingMovedEnough =
        lastHeading == null ||
        heading == null ||
        (heading - lastHeading!).abs() >= 0.5;

    if (elapsedSinceLastEmit < const Duration(milliseconds: 120) &&
        !headingMovedEnough) {
      return false;
    }

    lastHeading = heading;
    lastEmittedAt = now;
    return true;
  });
});
