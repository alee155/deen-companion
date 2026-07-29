import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/islamic_name_model.dart';

abstract class IslamicNamesRemoteDataSource {
  Future<List<IslamicNameModel>> getAllNames();
}

class IslamicNamesRemoteDataSourceImpl implements IslamicNamesRemoteDataSource {
  final Dio dio;
  const IslamicNamesRemoteDataSourceImpl(this.dio);

  @override
  Future<List<IslamicNameModel>> getAllNames() async {
    try {
      final response = await dio.get(ApiEndpoints.islamicNamesAll);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );
      final list = envelope.data['names'] as List;
      return list
          .map((e) => IslamicNameModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
