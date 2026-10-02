import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<dynamic> okResponse(Object? data, {int status = 200}) => Response(
  data: data,
  statusCode: status,
  requestOptions: RequestOptions(path: '/'),
);

DioException dioError([String message = 'boom']) => DioException(
  requestOptions: RequestOptions(path: '/'),
  message: message,
  type: DioExceptionType.connectionError,
);

/// Stubs the next `dio.get(<any>)` to return [data].
void stubGet(MockDio dio, Object? data, {int status = 200}) {
  when(
    () => dio.get(any()),
  ).thenAnswer((_) async => okResponse(data, status: status));
}

void stubGetThrows(MockDio dio, [Object? error]) {
  when(() => dio.get(any())).thenThrow(error ?? dioError());
}

/// Same as [stubGet] for calls that pass `options:` (e.g. validateStatus).
void stubGetWithOptions(MockDio dio, Object? data, {int status = 200}) {
  when(
    () => dio.get(any(), options: any(named: 'options')),
  ).thenAnswer((_) async => okResponse(data, status: status));
}

void registerDioFallbacks() {
  registerFallbackValue(Options());
}
