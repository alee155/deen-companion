import 'dart:async';

import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/logger.dart';
import '../../data/datasources/islamic_calendar_remote_datasource.dart';
import '../../data/repositories/islamic_calendar_repository_impl.dart';
import '../../domain/entities/hijri_conversion.dart';
import '../../domain/entities/islamic_event.dart';
import '../../domain/entities/islamic_month.dart';
import '../../domain/repositories/islamic_calendar_repository.dart';
import '../../../../core/usecase/usecase.dart';
import 'hijri_adjustment_provider.dart';

final islamicCalendarRemoteDataSourceProvider =
    Provider<IslamicCalendarRemoteDataSource>((ref) {
      return IslamicCalendarRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final islamicCalendarRepositoryProvider = Provider<IslamicCalendarRepository>((
  ref,
) {
  return IslamicCalendarRepositoryImpl(
    remoteDataSource: ref.watch(islamicCalendarRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

/// Powers both the Home screen greeting and the Islamic Calendar hub.
///
/// Deliberately uncached: always fetches live from the network, for both
/// today's date and any offset-adjusted date. A cached "today" is only ever
/// wrong for a few hours at worst, but a cached offset-adjusted conversion
/// was cached for up to a year and had already caused one real bug — not
/// worth the minor perf win of an instant-paint cache when this is a single
/// small request the user makes at most a few times per day.
class TodayHijriNotifier extends StreamNotifier<HijriConversion> {
  @override
  Stream<HijriConversion> build() async* {
    final offset = ref.watch(hijriAdjustmentProvider);
    final repo = ref.read(islamicCalendarRepositoryProvider);
    AppLogger.i('TodayHijri: fetching live with offset=$offset (no cache)');

    final result = offset == 0
        ? await repo.fetchTodayHijri(forceRefresh: true)
        : await _fetchShifted(repo, offset);

    yield result.when(
      success: (d) {
        AppLogger.i(
          'TodayHijri: offset=$offset result -> '
          '${d.hijri.day} ${d.hijri.monthName} ${d.hijri.year}',
        );
        return d;
      },
      failure: (f) {
        AppLogger.i('TodayHijri: offset=$offset failed -> $f');
        throw f;
      },
    );
  }

  // No local calendar arithmetic is done here — shifting the *Gregorian*
  // input date and asking the same remote conversion to resolve it keeps
  // month/year rollovers correct without us having to know Hijri month
  // lengths ourselves.
  Future<Result<HijriConversion>> _fetchShifted(
    IslamicCalendarRepository repo,
    int offset,
  ) {
    final shifted = DateTime.now().add(Duration(days: offset));
    AppLogger.i(
      'TodayHijri: shifted Gregorian date -> '
      '${shifted.year}-${shifted.month}-${shifted.day}',
    );
    return repo.convertGregorianToHijri(
      shifted.year,
      shifted.month,
      shifted.day,
      forceRefresh: true,
    );
  }
}

final todayHijriNotifierProvider =
    StreamNotifierProvider<TodayHijriNotifier, HijriConversion>(
      TodayHijriNotifier.new,
    );

class IslamicMonthsNotifier
    extends CacheFirstStreamNotifier<List<IslamicMonth>> {
  @override
  List<IslamicMonth>? readCache() =>
      ref.read(islamicCalendarRepositoryProvider).getCachedMonths();

  @override
  Future<Result<List<IslamicMonth>>> fetchFresh() =>
      ref.read(islamicCalendarRepositoryProvider).fetchAndCacheMonths();
}

final islamicMonthsNotifierProvider =
    StreamNotifierProvider<IslamicMonthsNotifier, List<IslamicMonth>>(
      IslamicMonthsNotifier.new,
    );

class IslamicEventsNotifier
    extends CacheFirstStreamNotifier<IslamicEventsBundle> {
  @override
  IslamicEventsBundle? readCache() =>
      ref.read(islamicCalendarRepositoryProvider).getCachedEvents();

  @override
  Future<Result<IslamicEventsBundle>> fetchFresh() =>
      ref.read(islamicCalendarRepositoryProvider).fetchAndCacheEvents();
}

final islamicEventsNotifierProvider =
    StreamNotifierProvider<IslamicEventsNotifier, IslamicEventsBundle>(
      IslamicEventsNotifier.new,
    );

// Converter — action-triggered, holds the current conversion result on screen.
class DateConverterNotifier extends AsyncNotifier<HijriConversion?> {
  @override
  FutureOr<HijriConversion?> build() => null;

  Future<void> convertGregorianToHijri(DateTime date) async {
    state = const AsyncLoading();
    final result = await ref
        .read(islamicCalendarRepositoryProvider)
        .convertGregorianToHijri(date.year, date.month, date.day);
    state = result.when(
      success: (d) => AsyncData(d),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
  }

  Future<void> convertHijriToGregorian(int year, int month, int day) async {
    state = const AsyncLoading();
    final result = await ref
        .read(islamicCalendarRepositoryProvider)
        .convertHijriToGregorian(year, month, day);
    state = result.when(
      success: (d) => AsyncData(d),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
  }
}

final dateConverterNotifierProvider =
    AsyncNotifierProvider<DateConverterNotifier, HijriConversion?>(
      DateConverterNotifier.new,
    );
