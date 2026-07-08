import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/zakat_calculation_model.dart';
import '../models/zakat_info_model.dart';
import '../models/zakat_nisab_model.dart';

abstract class ZakatRemoteDataSource {
  Future<ZakatInfoModel> getInfo();
  Future<ZakatNisabModel> getNisab({
    double? goldPricePerGram,
    double? silverPricePerGram,
  });
  Future<ZakatCalculateResponseModel> calculate(
    ZakatCalculateRequestModel request,
  );
  Future<ZakatAgricultureResponseModel> calculateAgriculture(
    ZakatAgricultureRequestModel request,
  );
}

class ZakatRemoteDataSourceImpl implements ZakatRemoteDataSource {
  final Dio dio;
  const ZakatRemoteDataSourceImpl(this.dio);

  @override
  Future<ZakatInfoModel> getInfo() async {
    try {
      final response = await dio.get(ApiEndpoints.zakatInfo);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        ZakatInfoModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<ZakatNisabModel> getNisab({
    double? goldPricePerGram,
    double? silverPricePerGram,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.zakatNisab(
          goldPricePerGram: goldPricePerGram,
          silverPricePerGram: silverPricePerGram,
        ),
      );
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        ZakatNisabModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<ZakatCalculateResponseModel> calculate(
    ZakatCalculateRequestModel request,
  ) async {
    try {
      final response = await dio.post(
        ApiEndpoints.zakatCalculate,
        data: request.toJson(),
      );
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        ZakatCalculateResponseModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<ZakatAgricultureResponseModel> calculateAgriculture(
    ZakatAgricultureRequestModel request,
  ) async {
    try {
      final response = await dio.post(
        ApiEndpoints.zakatAgriculture,
        data: request.toJson(),
      );
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        ZakatAgricultureResponseModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
