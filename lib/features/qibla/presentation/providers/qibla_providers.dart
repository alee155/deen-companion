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
final compassEventProvider = StreamProvider<CompassEvent?>((ref) {
  final events = FlutterCompass.events;
  return events ?? const Stream.empty();
});
