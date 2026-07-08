import '../../../../core/usecase/usecase.dart';
import '../entities/hijri_conversion.dart';
import '../entities/islamic_event.dart';
import '../entities/islamic_month.dart';

abstract class IslamicCalendarRepository {
  HijriConversion? getCachedTodayHijri();
  Future<Result<HijriConversion>> fetchTodayHijri({bool forceRefresh = false});

  Future<Result<HijriConversion>> convertGregorianToHijri(
    int year,
    int month,
    int day, {
    bool forceRefresh = false,
  });
  Future<Result<HijriConversion>> convertHijriToGregorian(
    int year,
    int month,
    int day, {
    bool forceRefresh = false,
  });

  List<IslamicMonth>? getCachedMonths();
  Future<Result<List<IslamicMonth>>> fetchAndCacheMonths({
    bool forceRefresh = false,
  });

  IslamicEventsBundle? getCachedEvents();
  Future<Result<IslamicEventsBundle>> fetchAndCacheEvents({
    bool forceRefresh = false,
  });
}
