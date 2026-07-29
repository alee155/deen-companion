import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/qibla_info_model.dart';

abstract class QiblaRemoteDataSource {
  Future<QiblaInfoModel> getQibla(double lat, double lng);
}

class QiblaRemoteDataSourceImpl implements QiblaRemoteDataSource {
  final Dio dio;
  const QiblaRemoteDataSourceImpl(this.dio);

  @override
  Future<QiblaInfoModel> getQibla(double lat, double lng) async {
    try {
      final response = await dio.get(ApiEndpoints.qibla(lat: lat, lng: lng));
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        QiblaInfoModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
