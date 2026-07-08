import 'dart:async';

import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/islamic_calendar_remote_datasource.dart';
import '../../data/repositories/islamic_calendar_repository_impl.dart';
import '../../domain/entities/hijri_conversion.dart';
import '../../domain/entities/islamic_event.dart';
import '../../domain/entities/islamic_month.dart';
import '../../domain/repositories/islamic_calendar_repository.dart';

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

class TodayHijriNotifier extends StreamNotifier<HijriConversion> {
  @override
  Stream<HijriConversion> build() async* {
    final repository = ref.watch(islamicCalendarRepositoryProvider);
    final cached = repository.getCachedTodayHijri();
    if (cached != null) yield cached;

    final result = await repository.fetchTodayHijri();
    final fresh = result.when(
      success: (d) => d,
      failure: (f) {
        if (cached == null) throw f;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }
}

final todayHijriNotifierProvider =
    StreamNotifierProvider<TodayHijriNotifier, HijriConversion>(
      TodayHijriNotifier.new,
    );

class IslamicMonthsNotifier extends StreamNotifier<List<IslamicMonth>> {
  @override
  Stream<List<IslamicMonth>> build() async* {
    final repository = ref.watch(islamicCalendarRepositoryProvider);
    final cached = repository.getCachedMonths();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheMonths();
    final fresh = result.when(
      success: (d) => d,
      failure: (f) {
        if (cached == null) throw f;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }
}

final islamicMonthsNotifierProvider =
    StreamNotifierProvider<IslamicMonthsNotifier, List<IslamicMonth>>(
      IslamicMonthsNotifier.new,
    );

class IslamicEventsNotifier extends StreamNotifier<IslamicEventsBundle> {
  @override
  Stream<IslamicEventsBundle> build() async* {
    final repository = ref.watch(islamicCalendarRepositoryProvider);
    final cached = repository.getCachedEvents();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheEvents();
    final fresh = result.when(
      success: (d) => d,
      failure: (f) {
        if (cached == null) throw f;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }
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
