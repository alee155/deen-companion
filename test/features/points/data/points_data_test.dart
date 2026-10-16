import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/core/utils/flow_log.dart';
import 'package:deen_companion/features/points/data/datasources/points_remote_datasource.dart';
import 'package:deen_companion/features/points/data/models/points_rule_model.dart';
import 'package:deen_companion/features/points/data/repositories/points_repository_impl.dart';
import 'package:deen_companion/features/points/domain/entities/points_rule.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_support/dio_test_support.dart';
import '../../_support/prayer_area_support.dart';
import '../_points_support.dart';

class _MockRemote extends Mock implements PointsRemoteDataSource {}

DioException _http(int status, Map<String, dynamic> body) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/'),
  ),
);

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('model', () {
    test('parses the documented response', () {
      final m = PointsRulesModel.fromList(sampleRulesJson);
      expect(m.rules, hasLength(5));
      expect(m.rules.first.prayer, 'fajr');
      expect(m.rules.first.points, 10);
      expect(m.toEntity(), sampleRules());
    });

    test('points may arrive as a decimal number', () {
      expect(
        PointsRuleModel.fromJson({'prayer': 'fajr', 'points': 10.0}).points,
        10,
      );
    });

    test('a missing field is an error, not a silent zero', () {
      expect(
        () => PointsRuleModel.fromJson({'prayer': 'fajr'}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => PointsRuleModel.fromJson({'points': 5}),
        throwsA(isA<TypeError>()),
      );
    });

    test('survives a round trip through the cache format', () {
      final m = PointsRulesModel.fromList(sampleRulesJson);
      expect(PointsRulesModel.fromJson(m.toJson()).toEntity(), m.toEntity());
    });
  });

  group('remote data source', () {
    late MockDio dio;
    late PointsRemoteDataSourceImpl ds;
    setUp(() {
      dio = MockDio();
      ds = PointsRemoteDataSourceImpl(dio);
    });

    test('asks GET /points/rules and parses the data list', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({'success': true, 'data': sampleRulesJson}),
      );
      final r = await ds.getRules();
      expect(r.rules, hasLength(5));
      verify(() => dio.get(ApiEndpoints.pointsRules)).called(1);
    });

    test('an empty table is fine', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({'success': true, 'data': <dynamic>[]}),
      );
      expect((await ds.getRules()).rules, isEmpty);
    });

    test('a 401 keeps the server message', () async {
      when(() => dio.get(any())).thenThrow(
        _http(401, {
          'success': false,
          'statusCode': 401,
          'message': 'Unauthorized',
        }),
      );
      await expectLater(
        ds.getRules(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.message, 'message', 'Unauthorized'),
        ),
      );
    });

    test('a connection error is a NetworkException', () async {
      when(() => dio.get(any())).thenThrow(dioError());
      await expectLater(ds.getRules(), throwsA(isA<NetworkException>()));
    });

    test('a body of the wrong shape is a ServerException', () async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': 'nope'}));
      await expectLater(ds.getRules(), throwsA(isA<ServerException>()));
    });

    test('success:false is a ServerException', () async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse({'success': false, 'message': 'x'}));
      await expectLater(ds.getRules(), throwsA(isA<ServerException>()));
    });

    test('an entry missing a field is a ServerException', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': [
            {'prayer': 'fajr'},
          ],
        }),
      );
      await expectLater(ds.getRules(), throwsA(isA<ServerException>()));
    });
  });

  group('repository', () {
    late _MockRemote remote;
    late PaStorage storage;
    late PointsRepositoryImpl repo;
    setUp(() {
      remote = _MockRemote();
      storage = PaStorage();
      repo = PointsRepositoryImpl(remote: remote, cacheStore: storage.cache);
    });

    test(
      'nothing cached at first',
      () => expect(repo.getCachedRules(), isNull),
    );

    test('a fetch returns the rules and caches them', () async {
      when(
        () => remote.getRules(),
      ).thenAnswer((_) async => PointsRulesModel.fromList(sampleRulesJson));
      final r = await repo.fetchRules();
      expect((r as Success<PointsRules>).data, sampleRules());
      expect(repo.getCachedRules(), sampleRules());
    });

    test('a failed fetch keeps the earlier cache', () async {
      when(
        () => remote.getRules(),
      ).thenAnswer((_) async => PointsRulesModel.fromList(sampleRulesJson));
      await repo.fetchRules();
      when(() => remote.getRules()).thenThrow(const NetworkException());
      expect(
        ((await repo.fetchRules()) as Error).failure,
        isA<NetworkFailure>(),
      );
      expect(repo.getCachedRules(), sampleRules());
    });

    test('a server error keeps its message', () async {
      when(() => remote.getRules()).thenThrow(const ServerException('Nope'));
      final f = ((await repo.fetchRules()) as Error).failure;
      expect(f, isA<ServerFailure>());
      expect(f.message, 'Nope');
    });

    test('a server error with no message is the generic one', () async {
      when(() => remote.getRules()).thenThrow(const ServerException());
      expect(
        ((await repo.fetchRules()) as Error).failure.message,
        const ServerFailure().message,
      );
    });

    test('anything unexpected is an UnexpectedFailure', () async {
      when(() => remote.getRules()).thenThrow(StateError('boom'));
      expect(
        ((await repo.fetchRules()) as Error).failure,
        isA<UnexpectedFailure>(),
      );
    });

    test('an unreadable cache is ignored instead of throwing', () {
      storage.seed('points_rules', {'rules': 'garbage'});
      expect(repo.getCachedRules(), isNull);
    });

    test('logs the fetch with the marker, and never anything secret', () async {
      final lines = <String>[];
      FlowLog.enabledOverride = true;
      FlowLog.sink = lines.add;
      addTearDown(() {
        FlowLog.enabledOverride = null;
        FlowLog.sink = null;
      });
      when(
        () => remote.getRules(),
      ).thenAnswer((_) async => PointsRulesModel.fromList(sampleRulesJson));
      await repo.fetchRules();
      expect(lines.any((l) => l.contains('[POINTS RULES] FETCHING')), isTrue);
      expect(lines.any((l) => l.contains('fajr: 10')), isTrue);
      for (final l in lines) {
        expect(l, startsWith('********** '));
        expect(l, endsWith(' **********'));
      }
    });
  });
}
