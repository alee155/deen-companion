import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../config/flavor_config.dart';
import 'interceptors/api_key_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(
        seconds: AppConstants.networkTimeoutSeconds,
      ),
      receiveTimeout: const Duration(
        seconds: AppConstants.networkTimeoutSeconds,
      ),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(ApiKeyInterceptor());

  if (FlavorConfig.instance.enableLogging) {
    dio.interceptors.add(LoggingInterceptor());
  }

  return dio;
});
