import 'package:deen_companion/core/network/interceptors/logging_interceptor.dart';
import 'package:deen_companion/core/utils/flow_log.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs one request through a real Dio with a stubbed adapter.
class _Adapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  late List<String> lines;
  late Dio dio;

  setUp(() {
    lines = [];
    FlowLog.enabledOverride = true;
    FlowLog.sink = lines.add;
    dio = Dio(BaseOptions(baseUrl: 'https://deencompanion.dgexpense.com/api'))
      ..interceptors.add(LoggingInterceptor());
  });

  tearDown(() {
    FlowLog.enabledOverride = null;
    FlowLog.sink = null;
  });

  String all() => lines.join('\n');

  test(
    'a request and its response share one API id and are in order',
    () async {
      dio.httpClientAdapter = _Adapter(
        (_) => _json('{"success":true,"data":{"days":[]}}', 200),
      );
      await dio.get('/prayers/times', queryParameters: {'days': 31});

      final started = lines.indexWhere((l) => l.contains('REQUEST STARTED'));
      final received = lines.indexWhere((l) => l.contains('RESPONSE RECEIVED'));
      expect(started, isNonNegative);
      expect(received, greaterThan(started));
      expect(lines[started], contains('GET /api/prayers/times'));
      expect(lines[received], contains('status 200'));

      final id = RegExp(r'\[API #(\d+)\]').firstMatch(lines[started])!.group(1);
      expect(lines[received], contains('[API #$id]'));
    },
  );

  test('prints the query and the response body', () async {
    dio.httpClientAdapter = _Adapter(
      (_) => _json('{"success":true,"data":{"days":[1,2,3,4]}}', 200),
    );
    await dio.get('/prayers/times', queryParameters: {'days': 31});
    expect(all(), contains('request query: {days: 31}'));
    expect(
      all(),
      contains('response body: {success: true, data: {days: [1, 2'),
    );
    expect(all(), contains('+2 more'));
  });

  test('every printed line is wrapped in the marker', () async {
    dio.httpClientAdapter = _Adapter((_) => _json('{"success":true}', 200));
    await dio.post('/groups', data: {'name': 'Family'});
    expect(lines, isNotEmpty);
    for (final l in lines) {
      expect(l, startsWith('********** '));
      expect(l, endsWith(' **********'));
    }
  });

  test('passwords, OTPs and e-mails in a request body never appear', () async {
    dio.httpClientAdapter = _Adapter(
      (_) => _json(
        '{"success":true,"data":{"accessToken":"SECRET.JWT.VALUE"}}',
        200,
      ),
    );
    await dio.post(
      '/auth/login',
      data: {
        'email': 'ali@example.com',
        'password': 'hunter2-secret',
        'otp': '4821',
        'newPassword': 'another-secret',
      },
    );
    final out = all();
    expect(out, contains('POST /api/auth/login'));
    for (final secret in [
      'hunter2-secret',
      '4821',
      'another-secret',
      'ali@example.com',
      'SECRET.JWT.VALUE',
    ]) {
      expect(out, isNot(contains(secret)), reason: secret);
    }
  });

  test('the token is never printed, only that one was sent', () async {
    dio.httpClientAdapter = _Adapter((_) => _json('{"success":true}', 200));
    await dio.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer eyJ.real.token'}),
    );
    expect(all(), contains('Auth: Bearer ***'));
    expect(all(), isNot(contains('eyJ.real.token')));
  });

  test('no token is reported as "none"', () async {
    dio.httpClientAdapter = _Adapter((_) => _json('{"success":true}', 200));
    await dio.get('/prayer-times');
    expect(all(), contains('Auth: none'));
  });

  test('the device id is shortened', () async {
    dio.httpClientAdapter = _Adapter((_) => _json('{"success":true}', 200));
    await dio.get(
      '/prayer-times',
      options: Options(
        headers: {'X-Device-Id': '1f3a9b2c-aaaa-4bbb-8ccc-123456789012'},
      ),
    );
    expect(all(), contains('X-Device-Id: 1f3a9b2c…'));
    expect(all(), isNot(contains('aaaa-4bbb')));
  });

  test('a server error shows its status, code and message', () async {
    dio.httpClientAdapter = _Adapter(
      (_) => _json(
        '{"success":false,"statusCode":409,"message":"Set your location first","code":"LOCATION_NOT_SET"}',
        409,
      ),
    );
    await expectLater(dio.get('/prayers/times'), throwsA(isA<DioException>()));
    final out = all();
    expect(out, contains('REQUEST FAILED  status 409'));
    expect(out, contains('error body:'));
    expect(out, contains('LOCATION_NOT_SET'));
    expect(out, contains('Set your location first'));
  });

  test('a connection error is reported without a status', () async {
    dio.httpClientAdapter = _Adapter(
      (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
        message: 'no route to host',
      ),
    );
    await expectLater(dio.get('/prayers/times'), throwsA(isA<DioException>()));
    expect(all(), contains('REQUEST FAILED  no response (connectionError)'));
    expect(all(), contains('error message: no route to host'));
  });

  test('a photo upload prints the file details, never the bytes', () async {
    dio.httpClientAdapter = _Adapter((_) => _json('{"success":true}', 201));
    await dio.post(
      '/prayers/logs',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          List.filled(1234, 7),
          filename: 'snap.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      }),
    );
    final out = all();
    expect(out, contains('file snap.jpg'));
    expect(out, contains('1234 bytes'));
    expect(out, contains('image/jpeg'));
    expect(out, isNot(contains('7, 7, 7')));
  });

  test('a third-party host is shown with its name', () async {
    dio.httpClientAdapter = _Adapter((_) => _json('{"data":{}}', 200));
    await dio.get('https://api.aladhan.com/v1/calendar/2026/10');
    expect(all(), contains('GET api.aladhan.com/v1/calendar/2026/10'));
  });

  test('prints nothing when logging is off', () async {
    FlowLog.enabledOverride = false;
    dio.httpClientAdapter = _Adapter((_) => _json('{"success":true}', 200));
    await dio.get('/prayers/times');
    expect(lines, isEmpty);
  });
}
