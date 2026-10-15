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
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
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

/// A bundle around [days] (Karachi / Hanafi, Asia/Karachi).
PrayerTimesBundle bundleOf(
  List<PrayerTimes> days, {
  List<String> lockedDates = const [],
  bool unverified = false,
}) => PrayerTimesBundle(
  location: const PrayerLocation(
    latitude: 31.52,
    longitude: 74.36,
    timezone: 'Asia/Karachi',
  ),
  method: const CalculationMethodInfo(
    id: 1,
    name: 'University of Islamic Sciences, Karachi',
    school: 'hanafi',
    schoolId: 1,
  ),
  days: [
    for (final d in days)
      PrayerTimesDay(
        date:
            '${d.fajr.year}-${d.fajr.month.toString().padLeft(2, '0')}-'
            '${d.fajr.day.toString().padLeft(2, '0')}',
        times: d,
      ),
  ],
  lockedDates: lockedDates,
  isUnverified: unverified,
);

/// In-memory [PrayerTimesRepository]. Tests either set [bundle] (what the
/// cache holds) or the older `months` helper, which is flattened into a
/// bundle so existing reminder / Do Not Disturb tests keep their shape.
class FakePrayerRepo implements PrayerTimesRepository {
  PrayerTimesBundle? bundle;
  final Map<int, Result<List<PrayerTimes>>> months = {};

  Result<PrayerTimesBundle> guestResult = const Error(NetworkFailure());
  Result<PrayerTimesBundle> putResult = const Error(NetworkFailure());
  Result<PrayerTimesBundle> accountResult = const Error(NetworkFailure());
  Result<SavedPrayerSettings> savedResult = const Success(
    SavedPrayerSettings(),
  );
  Result<PrayerTimesBundle> monthResult = const Error(NetworkFailure());
  Result<List<PrayerCity>> citiesResult = const Success([]);
  Result<List<CalculationMethodOption>> methodsResult = const Success([]);

  final List<String> calls = [];
  ({int? method, int? school})? lastSent;
  Coordinates? lastCoordinates;

  @override
  PrayerTimesBundle? getCachedBundle() {
    if (bundle != null) return bundle;
    final days = <PrayerTimes>[];
    for (final r in months.values) {
      if (r case Success(:final data)) {
        for (final d in data) {
          if (!days.contains(d)) days.add(d);
        }
      }
    }
    if (days.isEmpty) return null;
    days.sort((a, b) => a.fajr.compareTo(b.fajr));
    return bundleOf(days);
  }

  @override
  PrayerTimes? getCachedToday(DateTime now) {
    final b = getCachedBundle();
    return b == null || b.days.isEmpty ? null : b.days.first.times;
  }

  @override
  Future<Result<PrayerTimesBundle>> fetchGuestTimes(
    Coordinates coordinates, {
    int? method,
    int? school,
    int days = 31,
  }) async {
    calls.add('guestTimes');
    lastCoordinates = coordinates;
    lastSent = (method: method, school: school);
    return guestResult;
  }

  @override
  Future<Result<PrayerTimesBundle>> fetchGuestMonth(
    Coordinates coordinates, {
    required int year,
    required int month,
    int? method,
    int? school,
  }) async {
    calls.add('guestMonth $year-$month');
    lastSent = (method: method, school: school);
    return monthResult;
  }

  @override
  Future<Result<SavedPrayerSettings>> getSavedSettings() async {
    calls.add('getSaved');
    return savedResult;
  }

  @override
  Future<Result<PrayerTimesBundle>> putLocation(
    Coordinates coordinates, {
    int? method,
    int? school,
  }) async {
    calls.add('put');
    lastCoordinates = coordinates;
    lastSent = (method: method, school: school);
    return putResult;
  }

  @override
  Future<Result<PrayerTimesBundle>> fetchAccountTimes({int days = 31}) async {
    calls.add('accountTimes');
    return accountResult;
  }

  @override
  Future<Result<PrayerTimesBundle>> fetchAccountMonth({
    required int year,
    required int month,
  }) async {
    calls.add('accountMonth $year-$month');
    return monthResult;
  }

  @override
  Future<Result<void>> clearAccountLocation() async => const Success(null);

  @override
  Future<Result<List<PrayerCity>>> searchCities(String query) async {
    calls.add('cities $query');
    return citiesResult;
  }

  @override
  Future<Result<List<CalculationMethodOption>>> getMethods() async =>
      methodsResult;

  @override
  Future<void> clearCache() async => calls.add('clearCache');
}

/// A loader that never touches location, auth or the network: [refresh]
/// answers from the fake repository.
class FakePrayerTimesLoader extends PrayerTimesLoader {
  final FakePrayerRepo repo;
  int refreshes = 0;
  Result<PrayerTimesBundle>? result;

  FakePrayerTimesLoader(super.ref, this.repo);

  @override
  Future<Result<PrayerTimesBundle>> refresh({bool force = false}) async {
    refreshes++;
    final fixed = result;
    if (fixed != null) return fixed;
    final cached = repo.getCachedBundle();
    return cached == null ? const Error(NetworkFailure()) : Success(cached);
  }
}
