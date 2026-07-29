import 'dart:async';

import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/islamic_calendar_remote_datasource.dart';
import '../../data/repositories/islamic_calendar_repository_impl.dart';
import '../../domain/entities/hijri_conversion.dart';
import '../../domain/entities/islamic_event.dart';
import '../../domain/entities/islamic_month.dart';
import '../../domain/repositories/islamic_calendar_repository.dart';
import '../../../../core/usecase/usecase.dart';

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

class TodayHijriNotifier extends CacheFirstStreamNotifier<HijriConversion> {
  @override
  HijriConversion? readCache() =>
      ref.read(islamicCalendarRepositoryProvider).getCachedTodayHijri();

  @override
  Future<Result<HijriConversion>> fetchFresh() =>
      ref.read(islamicCalendarRepositoryProvider).fetchTodayHijri();
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
