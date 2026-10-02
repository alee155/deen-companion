import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/network/dio_client.dart';
import 'package:deen_companion/core/network/interceptors/api_key_interceptor.dart';
import 'package:deen_companion/core/network/interceptors/logging_interceptor.dart';
import 'package:deen_companion/core/network/network_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? last;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  FlavorConfig(flavor: Flavor.dev, enableLogging: false);

  group('ApiKeyInterceptor', () {
    Future<RequestOptions> send(String url) async {
      final adapter = _CaptureAdapter();
      final dio = Dio()
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiKeyInterceptor());
      await dio.get<dynamic>(url);
      return adapter.last!;
    }

    test('adds x-api-key for ummahapi.com hosts', () async {
      final o = await send('https://ummahapi.com/api/quran');
      expect(o.headers.containsKey('x-api-key'), isTrue);
      expect(o.headers['x-api-key'], FlavorConfig.instance.ummahApiKey);
    });

    test('does not leak the key to other hosts', () async {
      final o = await send('https://api.aladhan.com/v1/timings/1');
      expect(o.headers.containsKey('x-api-key'), isFalse);
    });
  });

  group('dioProvider', () {
    test('configures timeouts, JSON header and api-key interceptor', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final dio = c.read(dioProvider);
      const t = Duration(seconds: AppConstants.networkTimeoutSeconds);
      expect(dio.options.connectTimeout, t);
      expect(dio.options.receiveTimeout, t);
      expect(dio.options.headers['Content-Type'], 'application/json');
      expect(dio.interceptors.whereType<ApiKeyInterceptor>(), hasLength(1));
    });

    test('logging interceptor is omitted when logging is disabled', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        c.read(dioProvider).interceptors.whereType<LoggingInterceptor>(),
        isEmpty,
      );
    });
  });

  group('NetworkInfoImpl', () {
    late _MockConnectivity conn;
    late NetworkInfoImpl info;
    setUp(() {
      conn = _MockConnectivity();
      info = NetworkInfoImpl(conn);
    });

    test('wifi / mobile are connected', () async {
      when(
        () => conn.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      expect(await info.isConnected, isTrue);
      when(() => conn.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.mobile, ConnectivityResult.vpn],
      );
      expect(await info.isConnected, isTrue);
    });

    test('only none means offline', () async {
      when(
        () => conn.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      expect(await info.isConnected, isFalse);
    });

    test('empty result is optimistic (connected)', () async {
      when(() => conn.checkConnectivity()).thenAnswer((_) async => []);
      expect(await info.isConnected, isTrue);
    });

    test('platform error is optimistic (connected)', () async {
      when(() => conn.checkConnectivity()).thenThrow(Exception('channel'));
      expect(await info.isConnected, isTrue);
    });

    test('hanging platform call times out and counts as connected', () async {
      when(
        () => conn.checkConnectivity(),
      ).thenAnswer((_) => Completer<List<ConnectivityResult>>().future);
      expect(await info.isConnected, isTrue);
    });
  });
}
