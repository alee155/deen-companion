import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/streaks/data/datasources/streaks_remote_datasource.dart';
import 'package:deen_companion/features/streaks/data/models/streak_models.dart';
import 'package:deen_companion/features/streaks/data/repositories/streaks_repository_impl.dart';
import 'package:deen_companion/features/streaks/domain/entities/group_streaks.dart';
import 'package:deen_companion/features/streaks/domain/entities/streak_rule.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';
import '_streaks_support.dart';

class _MockRemote extends Mock implements StreaksRemoteDataSource {}

DioException _http(int status, String message) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: {'success': false, 'statusCode': status, 'message': message},
    requestOptions: RequestOptions(path: '/'),
  ),
);

const _ruleJson = {
  'minPrayers': 3,
  'effectiveFrom': '2026-10-01T00:00:00.000Z',
  'nextChange': null,
};

const _boardJson = [
  {
    'userId': 'u1',
    'name': 'Alee',
    'role': 'admin',
    'currentStreak': 5,
    'bestStreak': 9,
    'todayCount': 2,
    'todayRequired': 3,
    'todayQualified': false,
  },
  {
    'userId': 'u2',
    'name': 'Sara',
    'role': 'member',
    'currentStreak': 1,
    'bestStreak': 1,
    'todayCount': 3,
    'todayRequired': 3,
    'todayQualified': true,
  },
];

const _mineJson = {
  'groups': [
    {
      'groupId': 'g1',
      'name': 'Family',
      'currentStreak': 7,
      'bestStreak': 12,
      'minPrayers': 3,
    },
  ],
  'prayers': {
    'fajr': {'currentStreak': 12, 'bestStreak': 30},
    'isha': {'currentStreak': 0, 'bestStreak': 4},
    'witr': {'currentStreak': 9, 'bestStreak': 9},
  },
};

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('models', () {
    test('a rule', () {
      final r = streakRuleFromJson(Map<String, dynamic>.of(_ruleJson));
      expect(r.minPrayers, 3);
      expect(r.effectiveFrom, DateTime.utc(2026, 10, 1));
    });

    test('a board keeps the server order and reads every field', () {
      final b = groupStreakBoardFromJson(_boardJson);
      expect(b.entries.map((e) => e.userId), ['u1', 'u2']);
      expect(b.entries.first.role, GroupRole.admin);
      expect(b.entries.first.bestStreak, 9);
      expect(b.entries.last.todayQualified, isTrue);
    });

    test(
      'my streaks: groups and the five prayers; unknown prayers skipped',
      () {
        final m = myStreaksFromJson(Map<String, dynamic>.of(_mineJson));
        expect(m.groups.single.minPrayers, 3);
        expect(m.prayer(PrayerName.fajr).currentStreak, 12);
        expect(m.prayer(PrayerName.isha).bestStreak, 4);
        // Not in the response: zero, not an error.
        expect(m.prayer(PrayerName.asr).currentStreak, 0);
        expect(m.prayers.length, 2, reason: '"witr" is not a prayer we know');
      },
    );

    test('counts may arrive as decimals', () {
      final b = groupStreakBoardFromJson([
        {..._boardJson.first, 'currentStreak': 5.0},
      ]);
      expect(b.entries.first.currentStreak, 5);
    });

    test('a missing field is an error, not a silent zero', () {
      expect(
        () => groupStreakBoardFromJson([
          {'userId': 'u1'},
        ]),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('remote data source', () {
    late MockDio dio;
    late StreaksRemoteDataSourceImpl ds;
    setUp(() {
      dio = MockDio();
      ds = StreaksRemoteDataSourceImpl(dio);
    });

    test('rule: GET /groups/{id}/streak-rule', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({'success': true, 'data': _ruleJson}),
      );
      expect((await ds.getRule('g1')).minPrayers, 3);
      verify(() => dio.get(ApiEndpoints.groupStreakRule('g1'))).called(1);
    });

    test('setRule: PATCH with the minPrayers body', () async {
      when(() => dio.patch(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => okResponse({'success': true, 'data': _ruleJson}),
      );
      await ds.setRule('g1', 3);
      verify(
        () => dio.patch(
          ApiEndpoints.groupStreakRule('g1'),
          data: {'minPrayers': 3},
        ),
      ).called(1);
    });

    test('board: GET /groups/{id}/streaks', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({'success': true, 'data': _boardJson}),
      );
      expect((await ds.getBoard('g1')).entries, hasLength(2));
      verify(() => dio.get(ApiEndpoints.groupStreaks('g1'))).called(1);
    });

    test('mine: GET /users/me/streaks', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({'success': true, 'data': _mineJson}),
      );
      expect((await ds.getMine()).groups, hasLength(1));
      verify(() => dio.get(ApiEndpoints.myStreaks)).called(1);
    });

    test('a 403 keeps the server message', () async {
      when(() => dio.get(any())).thenThrow(_http(403, 'Not a member'));
      await expectLater(
        ds.getBoard('g1'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'message', 'Not a member'),
        ),
      );
    });

    test('a connection error is a NetworkException', () async {
      when(() => dio.get(any())).thenThrow(dioError());
      await expectLater(ds.getMine(), throwsA(isA<NetworkException>()));
    });

    test('a body of the wrong shape is a ServerException', () async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': 'nope'}));
      await expectLater(ds.getMine(), throwsA(isA<ServerException>()));
      await expectLater(ds.getBoard('g1'), throwsA(isA<ServerException>()));
    });

    test('an unparseable date is a ServerException', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': {'minPrayers': 1, 'effectiveFrom': 'soon'},
        }),
      );
      await expectLater(ds.getRule('g1'), throwsA(isA<ServerException>()));
    });
  });

  group('repository', () {
    late _MockRemote remote;
    late StreaksRepositoryImpl repo;
    setUp(() {
      remote = _MockRemote();
      repo = StreaksRepositoryImpl(remote);
    });

    test('passes data through as Success', () async {
      when(
        () => remote.getBoard('g1'),
      ).thenAnswer((_) async => GroupStreakBoard([entry('u1', current: 3)]));
      final r = await repo.getBoard('g1');
      expect(
        (r as Success<GroupStreakBoard>).data.entries.single.currentStreak,
        3,
      );
    });

    test('maps a network error', () async {
      when(() => remote.getMine()).thenThrow(const NetworkException());
      expect(((await repo.getMine()) as Error).failure, isA<NetworkFailure>());
    });

    test('keeps the server message on a rejection', () async {
      when(
        () => remote.setRule('g1', 3),
      ).thenThrow(const ServerException('Only the admin can do this', 403));
      final f = ((await repo.setRule('g1', 3)) as Error).failure;
      expect(f, isA<ServerFailure>());
      expect(f.message, 'Only the admin can do this');
    });

    test('maps anything unexpected', () async {
      when(() => remote.getRule('g1')).thenThrow(StateError('boom'));
      expect(
        ((await repo.getRule('g1')) as Error).failure,
        isA<UnexpectedFailure>(),
      );
    });

    test('setRule never sends a value the server would refuse', () async {
      for (final bad in [0, 6, -1]) {
        final r = await repo.setRule('g1', bad);
        expect(r, isA<Error>(), reason: '$bad');
      }
      verifyNever(() => remote.setRule(any(), any()));
    });

    test('setRule accepts every value from 1 to 5', () async {
      when(() => remote.setRule(any(), any())).thenAnswer(
        (_) async =>
            StreakRule(minPrayers: 2, effectiveFrom: DateTime.utc(2026)),
      );
      for (var n = 1; n <= 5; n++) {
        expect(await repo.setRule('g1', n), isA<Success>());
      }
    });
  });
}
