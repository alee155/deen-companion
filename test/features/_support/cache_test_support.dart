import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/network/network_info.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';

/// In-memory [LocalStorageService] so repository cache logic runs against the
/// real [HiveCacheStore] envelope format without touching Hive/platform code.
class InMemoryStorage implements LocalStorageService {
  final Map<String, Map<String, dynamic>> boxes = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    boxes.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  T? get<T>(String boxName, String key) => boxes[boxName]?[key] as T?;

  @override
  Future<void> delete(String boxName, String key) async {
    boxes[boxName]?.remove(key);
  }

  @override
  Map<String, dynamic> getAll(String boxName) =>
      Map<String, dynamic>.from(boxes[boxName] ?? {});

  @override
  Future<void> clearAll(String boxName) async => boxes[boxName]?.clear();

  @override
  Stream<void> watch(String boxName) => const Stream.empty();

  /// Whether anything is stored under [key] in the API cache box.
  bool hasCached(String key) =>
      boxes[AppConstants.apiCacheBoxName]?.containsKey(key) ?? false;

  /// Seeds the API cache box with the same envelope [HiveCacheStore.save]
  /// writes, optionally back-dated so the entry counts as stale.
  void seed(
    String key,
    Map<String, dynamic> data, {
    Duration age = Duration.zero,
  }) {
    boxes.putIfAbsent(AppConstants.apiCacheBoxName, () => {})[key] = {
      'data': data,
      'fetched_at': DateTime.now().subtract(age).toIso8601String(),
    };
  }

  /// Seeds a list payload the way the repositories wrap lists.
  void seedList(
    String key,
    List<Map<String, dynamic>> list, {
    Duration age = Duration.zero,
  }) => seed(key, {'list': list}, age: age);
}

class FakeNetworkInfo implements NetworkInfo {
  bool connected;
  FakeNetworkInfo({this.connected = true});

  @override
  Future<bool> get isConnected async => connected;
}

HiveCacheStore storeFor(InMemoryStorage storage) => HiveCacheStore(storage);
