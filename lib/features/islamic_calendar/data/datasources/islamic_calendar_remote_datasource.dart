import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/hijri_conversion_model.dart';
import '../models/islamic_events_bundle_model.dart';
import '../models/islamic_month_model.dart';

abstract class IslamicCalendarRemoteDataSource {
  Future<HijriConversionModel> getTodayHijri();
  Future<HijriConversionModel> getHijriDate(int year, int month, int day);
  Future<HijriConversionModel> getGregorianDate(int year, int month, int day);
  Future<List<IslamicMonthModel>> getIslamicMonths();
  Future<IslamicEventsBundleModel> getIslamicEvents();
}

class IslamicCalendarRemoteDataSourceImpl
    implements IslamicCalendarRemoteDataSource {
  final Dio dio;
  const IslamicCalendarRemoteDataSourceImpl(this.dio);

  @override
  Future<HijriConversionModel> getTodayHijri() async {
    try {
      final response = await dio.get(ApiEndpoints.todayHijri);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        HijriConversionModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<HijriConversionModel> getHijriDate(
    int year,
    int month,
    int day,
  ) async {
    try {
      final response = await dio.get(
        ApiEndpoints.hijriDate(year: year, month: month, day: day),
      );
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        HijriConversionModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<HijriConversionModel> getGregorianDate(
    int year,
    int month,
    int day,
  ) async {
    try {
      final response = await dio.get(
        ApiEndpoints.gregorianDate(year: year, month: month, day: day),
      );
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        HijriConversionModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<IslamicMonthModel>> getIslamicMonths() async {
    try {
      final response = await dio.get(ApiEndpoints.islamicMonths);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );
      final list = envelope.data['months'] as List;
      return list
          .map((e) => IslamicMonthModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<IslamicEventsBundleModel> getIslamicEvents() async {
    try {
      final response = await dio.get(ApiEndpoints.islamicEvents);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        IslamicEventsBundleModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
