import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../storage/local_storage_service.dart';
import 'cached_result.dart';

/// Recursively converts Hive's untyped Map<dynamic,dynamic> / List<dynamic>
/// results into the Map<String, dynamic> shape every fromJson() expects.
dynamic _deepConvert(dynamic value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), _deepConvert(v)));
  }
  if (value is List) {
    return value.map(_deepConvert).toList();
  }
  return value;
}

class HiveCacheStore {
  final LocalStorageService storage;
  const HiveCacheStore(this.storage);

  Future<void> save<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final envelope = {
      'data': toJson(data),
      'fetched_at': DateTime.now().toIso8601String(),
    };
    await storage.put(AppConstants.apiCacheBoxName, key, envelope);
  }

  CachedResult<T>? read<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = storage.get<Map>(AppConstants.apiCacheBoxName, key);
    if (raw == null) return null;

    final dataMap = _deepConvert(raw['data']) as Map<String, dynamic>;
    final fetchedAt = DateTime.parse(raw['fetched_at'] as String);

    return CachedResult(data: fromJson(dataMap), fetchedAt: fetchedAt);
  }
}

final hiveCacheStoreProvider = Provider<HiveCacheStore>((ref) {
  return HiveCacheStore(ref.watch(localStorageServiceProvider));
});
