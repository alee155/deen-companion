import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/prayer_times_bundle.dart';
import '../../domain/prayer_day_selector.dart';
import '../../domain/prayer_times_failure.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../datasources/aladhan_fallback_datasource.dart';
import '../datasources/prayer_times_remote_datasource.dart';
import '../models/prayer_times_model.dart';
import '../models/server_prayer_times_models.dart';

/// The last bundle fetched from the server: up to 31 days, enough for
/// reminders to keep working offline. One entry, not a history.
const _bundleKey = 'prayer_times_bundle';
const _monthPrefix = 'prayer_times_month_';

const _tag = 'REPOSITORY';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  final PrayerTimesRemoteDataSource remote;
  final AladhanFallbackDataSource fallback;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const PrayerTimesRepositoryImpl({
    required this.remote,
    required this.fallback,
    required this.cacheStore,
    required this.networkInfo,
  });

  // ── Cache ───────────────────────────────────────────────────────────────

  @override
  PrayerTimesBundle? getCachedBundle() {
    try {
      final cached = cacheStore.read<PrayerTimesBundleModel>(
        _bundleKey,
        PrayerTimesBundleModel.fromJson,
      );
      final bundle = cached?.data.toEntity();
      FlowLog.log(
        _tag,
        bundle == null
            ? 'CACHE READ: nothing cached yet'
            : 'CACHE READ: ${bundle.days.length} days, saved ${cached!.fetchedAt}',
      );
      return bundle;
    } catch (e, st) {
      FlowLog.error(_tag, 'CACHE UNREADABLE, ignoring it', e);
      // A cache written by an older build must never break the screen.
      AppLogger.e('PrayerTimes: unreadable cache ignored', e, st);
      return null;
    }
  }

  @override
  PrayerTimes? getCachedToday(DateTime now) {
    final bundle = getCachedBundle();
    return bundle == null ? null : todayOf(bundle.days, now);
  }

  Future<void> _cacheBundle(PrayerTimesBundleModel model) {
    FlowLog.log(
      _tag,
      'CACHE SAVED: ${(model.raw['days'] as List).length} days',
    );
    return cacheStore.save<PrayerTimesBundleModel>(
      _bundleKey,
      model,
      (m) => m.toJson(),
    );
  }

  @override
  Future<void> clearCache() async {
    FlowLog.log(_tag, 'CACHE CLEARED (bundle and cached months)');
    final storage = cacheStore.storage;
    const box = AppConstants.apiCacheBoxName;
    final keys = storage
        .getAll(box)
        .keys
        .where((k) => k == _bundleKey || k.startsWith(_monthPrefix))
        .toList();
    for (final key in keys) {
      await storage.delete(box, key);
    }
  }

  // ── Guests ──────────────────────────────────────────────────────────────

  @override
  Future<Result<PrayerTimesBundle>> fetchGuestTimes(
    Coordinates coordinates, {
    int? method,
    int? school,
    int days = 31,
  }) => _bundle(
    () => remote.guestTimes(
      coordinates,
      method: method,
      school: school,
      days: days,
    ),
    cache: true,
    fallbackFor: (c) => _fallbackBundle(coordinates, method, school),
  );

  @override
  Future<Result<PrayerTimesBundle>> fetchGuestMonth(
    Coordinates coordinates, {
    required int year,
    required int month,
    int? method,
    int? school,
  }) => _bundle(
    () => remote.guestMonth(
      coordinates,
      year: year,
      month: month,
      method: method,
      school: school,
    ),
    monthKey: _monthKey(year, month),
  );

  // ── Signed in ───────────────────────────────────────────────────────────

  @override
  Future<Result<SavedPrayerSettings>> getSavedSettings() =>
      _guard(remote.getSavedSettings);

  @override
  Future<Result<PrayerTimesBundle>> putLocation(
    Coordinates coordinates, {
    int? method,
    int? school,
  }) => _bundle(
    () => remote.putLocation(coordinates, method: method, school: school),
    cache: true,
  );

  @override
  Future<Result<PrayerTimesBundle>> fetchAccountTimes({int days = 31}) =>
      _bundle(() => remote.accountTimes(days: days), cache: true);

  @override
  Future<Result<PrayerTimesBundle>> fetchAccountMonth({
    required int year,
    required int month,
  }) => _bundle(
    () => remote.accountMonth(year: year, month: month),
    monthKey: _monthKey(year, month),
  );

  @override
  Future<Result<void>> clearAccountLocation() async {
    final result = await _guard(remote.clearLocation);
    if (result is Success) await clearCache();
    return result;
  }

  // ── Both ────────────────────────────────────────────────────────────────

  @override
  Future<Result<List<PrayerCity>>> searchCities(String query) =>
      _guard(() => remote.searchCities(query));

  @override
  Future<Result<List<CalculationMethodOption>>> getMethods() =>
      _guard(remote.getMethods);

  // ── Plumbing ────────────────────────────────────────────────────────────

  /// Fetches a bundle, optionally caching it. [fallbackFor] runs only when
  /// the server could not be reached *and* nothing is cached, so a good
  /// cache is never replaced by unverified times.
  ///
  /// A [monthKey] makes this a calendar month: it is cached on its own and
  /// served from there when the request fails, so a visited month still opens
  /// offline.
  Future<Result<PrayerTimesBundle>> _bundle(
    Future<PrayerTimesBundleModel> Function() fetch, {
    bool cache = false,
    String? monthKey,
    Future<PrayerTimesBundle?> Function(Failure failure)? fallbackFor,
  }) async {
    final result = await _guard(fetch);
    switch (result) {
      case Success(:final data):
        if (cache) await _cacheBundle(data);
        if (monthKey != null) {
          FlowLog.log(_tag, 'MONTH CACHED: $monthKey');
          await cacheStore.save<PrayerTimesBundleModel>(
            monthKey,
            data,
            (m) => m.toJson(),
          );
        }
        return Success(data.toEntity());
      case Error(:final failure):
        if (monthKey != null) {
          final cached = _readMonth(monthKey);
          if (cached != null) {
            FlowLog.log(
              _tag,
              'MONTH REQUEST FAILED (${failure.message}) -> SHOWING THE CACHED MONTH',
            );
            return Success(cached);
          }
        }
        if (fallbackFor != null &&
            _serverUnreachable(failure) &&
            getCachedBundle() == null) {
          FlowLog.log(
            _tag,
            'SERVER UNREACHABLE (${failure.message}) AND NOTHING CACHED -> TRYING ALADHAN DIRECTLY',
          );
          final unverified = await fallbackFor(failure);
          if (unverified != null) {
            FlowLog.log(
              _tag,
              'ALADHAN FALLBACK USED: ${unverified.days.length} days, UNVERIFIED, not saved',
            );
            return Success(unverified);
          }
        }
        FlowLog.error(_tag, 'REQUEST FAILED', failure.message);
        return Error(failure);
    }
  }

  /// A network error or a 5xx: the server, not the request, is the problem.
  static bool _serverUnreachable(Failure f) =>
      f is NetworkFailure ||
      (f is PrayerTimesFailure && (f.statusCode ?? 0) >= 500);

  Future<PrayerTimesBundle?> _fallbackBundle(
    Coordinates coordinates,
    int? method,
    int? school,
  ) async {
    final now = DateTime.now();
    final m = method ?? 1;
    final s = school ?? 1;
    try {
      final models = await fallback.getMonthCalendar(
        coordinates,
        year: now.year,
        month: now.month,
        method: m,
        school: s,
      );
      final days = [
        for (var i = 0; i < models.length; i++)
          PrayerTimesDay(
            date: _dateOf(models[i].fajr),
            times: models[i].toEntity(),
          ),
      ];
      if (days.isEmpty) return null;
      AppLogger.i(
        'PrayerTimes: server unreachable, using Aladhan (unverified)',
      );
      return PrayerTimesBundle(
        location: PrayerLocation(
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
          timezone: '',
        ),
        method: CalculationMethodInfo(
          id: m,
          name: '',
          school: s == 1 ? 'hanafi' : 'standard',
          schoolId: s,
        ),
        days: days,
        isUnverified: true,
      );
    } catch (e, st) {
      AppLogger.e('PrayerTimes: Aladhan fallback failed', e, st);
      return null;
    }
  }

  static String _monthKey(int year, int month) =>
      '$_monthPrefix${year.toString().padLeft(4, '0')}_'
      '${month.toString().padLeft(2, '0')}';

  PrayerTimesBundle? _readMonth(String key) {
    try {
      return cacheStore
          .read<PrayerTimesBundleModel>(key, PrayerTimesBundleModel.fromJson)
          ?.data
          .toEntity();
    } catch (_) {
      return null;
    }
  }

  static String _dateOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    if (!await networkInfo.isConnected) return const Error(NetworkFailure());
    try {
      return Success(await body());
    } on NetworkException {
      return const Error(NetworkFailure());
    } on ServerException catch (e) {
      return Error(
        PrayerTimesFailure(
          e.message ?? const ServerFailure().message,
          code: PrayerTimesErrorCode.parse(e.code, e.statusCode),
          statusCode: e.statusCode,
        ),
      );
    } catch (e, st) {
      AppLogger.e('PrayerTimesRepository failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
