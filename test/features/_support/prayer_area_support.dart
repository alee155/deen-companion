import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/network/network_info.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/domain/repositories/prayer_times_repository.dart';

/// AppLogger.i asserts FlavorConfig exists; call once from setUpAll.
void initFlavorForTests() {
  FlavorConfig(flavor: Flavor.dev, enableLogging: false);
}

/// In-memory storage that mimics Hive: nested maps come back as
/// a dynamic-keyed Map, so HiveCacheStore's deep conversion is exercised.
class PaStorage implements LocalStorageService {
  final Map<String, Map<String, dynamic>> boxes = {};

  dynamic _hiveify(dynamic v) {
    if (v is Map) {
      return Map<dynamic, dynamic>.fromEntries(
        v.entries.map((e) => MapEntry(e.key, _hiveify(e.value))),
      );
    }
    if (v is List) return v.map(_hiveify).toList();
    return v;
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    boxes.putIfAbsent(boxName, () => {})[key] = _hiveify(value);
  }

  @override
  T? get<T>(String boxName, String key) => boxes[boxName]?[key] as T?;

  @override
  Future<void> delete(String boxName, String key) async =>
      boxes[boxName]?.remove(key);

  @override
  Map<String, dynamic> getAll(String boxName) =>
      Map<String, dynamic>.from(boxes[boxName] ?? {});

  @override
  Future<void> clearAll(String boxName) async => boxes[boxName]?.clear();

  @override
  Stream<void> watch(String boxName) => const Stream.empty();

  bool hasCached(String key) =>
      boxes[AppConstants.apiCacheBoxName]?.containsKey(key) ?? false;

  /// Writes a cache envelope exactly like HiveCacheStore.save, optionally
  /// back-dated.
  void seed(
    String key,
    Map<String, dynamic> data, {
    Duration age = Duration.zero,
  }) {
    boxes.putIfAbsent(AppConstants.apiCacheBoxName, () => {})[key] = _hiveify({
      'data': data,
      'fetched_at': DateTime.now().subtract(age).toIso8601String(),
    });
  }

  HiveCacheStore get cache => HiveCacheStore(this);
}

class PaNetwork implements NetworkInfo {
  bool connected;
  PaNetwork([this.connected = true]);

  @override
  Future<bool> get isConnected async => connected;
}

/// Location service whose behaviour is set per test.
class PaLocation implements LocationService {
  Coordinates? coordinates = const Coordinates(
    latitude: 21.4225,
    longitude: 39.8262,
  );
  LocationServiceException? error;
  int calls = 0;
  LocationAvailability availability = const LocationAvailability(
    serviceEnabled: true,
    hasPermission: true,
    permanentlyDenied: false,
  );
  LocationAvailability requestResult = const LocationAvailability(
    serviceEnabled: true,
    hasPermission: true,
    permanentlyDenied: false,
  );
  int openAppSettingsCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<Coordinates> getCurrentCoordinates({
    bool requestPermission = true,
  }) async {
    calls++;
    if (error != null) throw error!;
    return coordinates!;
  }

  @override
  Coordinates? lastStoredCoordinates() => coordinates;

  @override
  Future<LocationAvailability> checkAvailability() async => availability;

  @override
  Future<LocationAvailability> requestPermission() async {
    requestPermissionCalls++;
    return requestResult;
  }

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openAppSettings() async => openAppSettingsCalls++;

  @override
  Stream<void> serviceStatusChanges() => const Stream.empty();
}

LocationServiceException locErr(LocationErrorKind k, [String? m]) =>
    LocationServiceException(k, m);

PrayerTimes pt(int day, {int fajr = 5}) => PrayerTimes(
  fajr: DateTime(2026, 9, day, fajr),
  dhuhr: DateTime(2026, 9, day, 12),
  asr: DateTime(2026, 9, day, 15),
  maghrib: DateTime(2026, 9, day, 18),
  isha: DateTime(2026, 9, day, 19),
  hijriDate: 'h',
);

class FakePrayerRepo implements PrayerTimesRepository {
  PrayerTimes? cached;
  Result<PrayerTimes> fetchResult = Success(pt(30));
  final Map<int, Result<List<PrayerTimes>>> months = {};
  final List<({int year, int month, int method, int school})> monthCalls = [];
  int? lastMethod;
  int? lastSchool;
  int fetchCalls = 0;

  @override
  PrayerTimes? getCachedPrayerTimesForLastKnownLocation() => cached;

  @override
  Future<Result<PrayerTimes>> fetchAndCachePrayerTimes({
    required int method,
    required int school,
    bool forceRefresh = false,
  }) async {
    fetchCalls++;
    lastMethod = method;
    lastSchool = school;
    return fetchResult;
  }

  @override
  Future<Result<List<PrayerTimes>>> fetchMonthCalendar({
    required int year,
    required int month,
    required int method,
    required int school,
  }) async {
    monthCalls.add((year: year, month: month, method: method, school: school));
    return months[month] ?? const Error(NetworkFailure());
  }
}
