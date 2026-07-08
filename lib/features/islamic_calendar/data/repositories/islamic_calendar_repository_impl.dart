import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/hijri_conversion.dart';
import '../../domain/entities/islamic_event.dart';
import '../../domain/entities/islamic_month.dart';
import '../../domain/repositories/islamic_calendar_repository.dart';
import '../datasources/islamic_calendar_remote_datasource.dart';
import '../models/hijri_conversion_model.dart';
import '../models/islamic_events_bundle_model.dart';
import '../models/islamic_month_model.dart';

class IslamicCalendarRepositoryImpl implements IslamicCalendarRepository {
  final IslamicCalendarRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const IslamicCalendarRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _todayCacheKey = 'islamic_today_hijri';
  static const _monthsCacheKey = 'islamic_months';
  static const _eventsCacheKey = 'islamic_events';

  static const _monthsCacheTtl = Duration(days: 90); // static reference data
  static const _conversionCacheTtl = Duration(
    days: 365,
  ); // deterministic — never changes
  static const _eventsCacheTtl = Duration(
    hours: 12,
  ); // contains time-relative "next event"

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _g2hCacheKey(int y, int m, int d) => 'islamic_g2h_${y}_${m}_$d';
  String _h2gCacheKey(int y, int m, int d) => 'islamic_h2g_${y}_${m}_$d';

  @override
  HijriConversion? getCachedTodayHijri() {
    final cached = cacheStore.read(
      _todayCacheKey,
      HijriConversionModel.fromJson,
    );
    if (cached == null) return null;
    // Wrapped date check reuses the "fetched_at" already stored by HiveCacheStore —
    // if it's stale by even a few hours it's still today's date, so we accept it
    // as long as it was cached today (a simple day-boundary check).
    final fetchedDay =
        '${cached.fetchedAt.year}-${cached.fetchedAt.month.toString().padLeft(2, '0')}-${cached.fetchedAt.day.toString().padLeft(2, '0')}';
    if (fetchedDay != _todayKey()) return null;
    return cached.data.toEntity();
  }

  @override
  Future<Result<HijriConversion>> fetchTodayHijri({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedTodayHijri();
      if (cached != null) return Success(cached);
    }

    if (!await networkInfo.isConnected) {
      final stale = cacheStore.read(
        _todayCacheKey,
        HijriConversionModel.fromJson,
      );
      if (stale != null) return Success(stale.data.toEntity());
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getTodayHijri();
      await cacheStore.save(_todayCacheKey, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final stale = cacheStore.read(
        _todayCacheKey,
        HijriConversionModel.fromJson,
      );
      if (stale != null) return Success(stale.data.toEntity());
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'IslamicCalendarRepository: unexpected error (today)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<HijriConversion>> convertGregorianToHijri(
    int year,
    int month,
    int day, {
    bool forceRefresh = false,
  }) async {
    final key = _g2hCacheKey(year, month, day);

    if (!forceRefresh) {
      final cached = cacheStore.read(key, HijriConversionModel.fromJson);
      if (cached != null && !cached.isStale(_conversionCacheTtl))
        return Success(cached.data.toEntity());
    }

    if (!await networkInfo.isConnected) {
      final cached = cacheStore.read(key, HijriConversionModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getHijriDate(year, month, day);
      await cacheStore.save(key, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = cacheStore.read(key, HijriConversionModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'IslamicCalendarRepository: unexpected error (g2h)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<HijriConversion>> convertHijriToGregorian(
    int year,
    int month,
    int day, {
    bool forceRefresh = false,
  }) async {
    final key = _h2gCacheKey(year, month, day);

    if (!forceRefresh) {
      final cached = cacheStore.read(key, HijriConversionModel.fromJson);
      if (cached != null && !cached.isStale(_conversionCacheTtl))
        return Success(cached.data.toEntity());
    }

    if (!await networkInfo.isConnected) {
      final cached = cacheStore.read(key, HijriConversionModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getGregorianDate(year, month, day);
      await cacheStore.save(key, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = cacheStore.read(key, HijriConversionModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'IslamicCalendarRepository: unexpected error (h2g)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  List<IslamicMonth>? getCachedMonths() {
    final cached = cacheStore.read<List<dynamic>>(
      _monthsCacheKey,
      (json) => json['list'] as List<dynamic>,
    );
    return cached?.data
        .map(
          (e) =>
              IslamicMonthModel.fromJson(e as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Result<List<IslamicMonth>>> fetchAndCacheMonths({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedRaw = cacheStore.read<List<dynamic>>(
        _monthsCacheKey,
        (json) => json['list'] as List<dynamic>,
      );
      if (cachedRaw != null && !cachedRaw.isStale(_monthsCacheTtl))
        return Success(getCachedMonths()!);
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedMonths();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.getIslamicMonths();
      await cacheStore.save<List<dynamic>>(
        _monthsCacheKey,
        models.map((m) => m.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      final cached = getCachedMonths();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'IslamicCalendarRepository: unexpected error (months)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  IslamicEventsBundle? getCachedEvents() {
    final cached = cacheStore.read(
      _eventsCacheKey,
      IslamicEventsBundleModel.fromJson,
    );
    if (cached == null) return null;
    return IslamicEventsBundle(
      currentDate: cached.data.currentDate.toEntity(),
      nextEvent: cached.data.nextEvent.toEntity(),
      events: cached.data.events.map((e) => e.toEntity()).toList(),
    );
  }

  @override
  Future<Result<IslamicEventsBundle>> fetchAndCacheEvents({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cacheStore.read(
        _eventsCacheKey,
        IslamicEventsBundleModel.fromJson,
      );
      if (cached != null && !cached.isStale(_eventsCacheTtl))
        return Success(getCachedEvents()!);
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedEvents();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getIslamicEvents();
      await cacheStore.save(_eventsCacheKey, model, (m) => m.toJson());
      return Success(
        IslamicEventsBundle(
          currentDate: model.currentDate.toEntity(),
          nextEvent: model.nextEvent.toEntity(),
          events: model.events.map((e) => e.toEntity()).toList(),
        ),
      );
    } on ServerException catch (e) {
      final cached = getCachedEvents();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'IslamicCalendarRepository: unexpected error (events)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }
}
