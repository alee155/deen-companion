import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:deen_companion/features/statistics/data/models/stats_models.dart';
import 'package:deen_companion/features/statistics/data/repositories/statistics_repository_impl.dart';
import 'package:deen_companion/features/statistics/domain/entities/group_stats.dart';
import 'package:deen_companion/features/statistics/domain/entities/personal_stats.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';
import '_stats_support.dart';

class _MockRemote extends Mock implements StatisticsRemoteDataSource {}

DioException _http(int status, String message) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: {'success': false, 'statusCode': status, 'message': message},
    requestOptions: RequestOptions(path: '/'),
  ),
);

Response<dynamic> ok(Object? data) =>
    okResponse({'success': true, 'data': data});

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('models', () {
    test('personal summary', () {
      final s = personalSummaryFromJson(summaryJson());
      expect(s.range.from, '2026-09-20');
      expect(s.totals.points, 640);
      expect(s.completion.percent, 82.5);
      expect(s.completion.possiblePrayers, 140);
      expect(s.strongest, PrayerName.dhuhr);
      expect(s.weakest, PrayerName.fajr);
      expect(s.statFor(PrayerName.fajr)?.currentStreak, 12);
      expect(s.statFor(PrayerName.asr), isNull);
    });

    test('no completed days: percent is null, not zero', () {
      final json = summaryJson()
        ..['completion'] = {
          'percent': null,
          'loggedPrayers': 0,
          'possiblePrayers': 0,
          'completedDays': 0,
        }
        ..['strongestPrayer'] = null
        ..['weakestPrayer'] = null;
      final s = personalSummaryFromJson(json);
      expect(s.completion.percent, isNull);
      expect(s.strongest, isNull);
      expect(s.weakest, isNull);
    });

    test('an unknown prayer in perPrayer is skipped', () {
      final json = summaryJson();
      (json['perPrayer'] as List).add({
        'prayer': 'witr',
        'count': 1,
        'percentOfCompletedDays': 1,
        'points': 1,
      });
      expect(personalSummaryFromJson(json).perPrayer, hasLength(2));
    });

    test('daily rows, with the five prayer booleans', () {
      final d = dailyListFromJson(dailyJson());
      expect(d, hasLength(3));
      expect(d.first.did(PrayerName.isha), isTrue);
      expect(d[1].prayersLogged, 0);
      expect(d.last.isToday, isTrue);
      expect(d.last.did(PrayerName.asr), isFalse);
      expect(d.last.day, DateTime(2026, 10, 19));
    });

    test('trend: oldest first, partial week flagged, null completion kept', () {
      final t = trendFromJson(trendJson());
      expect(t.map((p) => p.label), ['5 Oct', '12 Oct', '19 Oct']);
      expect(t.last.isCurrent, isTrue);
      expect(t.last.completionPercent, isNull);
      expect(t.first.completionPercent, 85.7);
    });

    test('group overview', () {
      final o = groupOverviewFromJson(overviewJson());
      expect(o.memberCount, 8);
      expect(o.totals.membersActiveToday, 6);
      expect(o.averageParticipationPercent, 74.5);
      expect(o.daily.last.isToday, isTrue);
      expect(o.daily.first.participationPercent, 75);
    });

    test('group members keep the server order; null completion stays null', () {
      final m = groupMembersFromJson(membersJson());
      expect(m.map((e) => e.userId), ['u1', 'u2', 'u3']);
      expect(m.first.role, GroupRole.admin);
      expect(m.last.completionPercent, isNull);
      expect(m[1].currentStreak, 9);
    });

    test('member detail', () {
      final d = memberDetailFromJson(memberDetailJson());
      expect(d.member.name, 'Sara');
      expect(d.member.joinedAt, DateTime.utc(2026, 9, 1, 8));
      expect(d.daily, hasLength(3));
      expect(
        d.perPrayer.single.currentStreak,
        isNull,
        reason: 'streaks are only on the personal summary',
      );
    });

    test(
      'attention: unknown flags are dropped, and so are members left with none',
      () {
        final r = attentionFromJson(attentionJson());
        expect(r.inactiveDaysThreshold, 3);
        expect(r.members.map((m) => m.userId), ['u3', 'u4']);
        expect(r.members.first.flags, [AttentionFlag.neverLogged]);
        expect(r.members.last.flags, [
          AttentionFlag.inactive,
          AttentionFlag.declining,
        ]);
        expect(r.members.last.daysSinceLastLog, 9);
        expect(r.members.first.lastLoggedDate, isNull);
      },
    );

    test('whole numbers may arrive as decimals and vice versa', () {
      final json = overviewJson();
      json['totals'] = <String, dynamic>{
        'prayersLogged': 400.0,
        'points': 2100.0,
        'perfectMemberDays': 14,
        'membersActiveToday': 6,
      };
      json['averageParticipationPercent'] = 75; // an int
      final o = groupOverviewFromJson(json);
      expect(o.totals.points, 2100);
      expect(o.averageParticipationPercent, 75.0);
    });

    test('a missing required field is an error, not a silent zero', () {
      final json = overviewJson()..remove('memberCount');
      expect(() => groupOverviewFromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('remote data source', () {
    late MockDio dio;
    late StatisticsRemoteDataSourceImpl ds;
    setUp(() {
      dio = MockDio();
      ds = StatisticsRemoteDataSourceImpl(dio);
    });

    void answer(Object? data) => when(
      () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer((_) async => ok(data));

    test(
      'summary: GET /users/me/stats/summary with only the params given',
      () async {
        answer(summaryJson());
        await ds.mySummary();
        verify(
          () => dio.get(ApiEndpoints.myStatsSummary, queryParameters: {}),
        ).called(1);
        await ds.mySummary(from: '2026-10-01');
        verify(
          () => dio.get(
            ApiEndpoints.myStatsSummary,
            queryParameters: {'from': '2026-10-01'},
          ),
        ).called(1);
      },
    );

    test('daily: GET /users/me/stats/daily', () async {
      answer(dailyJson());
      expect(await ds.myDaily(), hasLength(3));
      verify(
        () => dio.get(ApiEndpoints.myStatsDaily, queryParameters: {}),
      ).called(1);
    });

    test('trend sends granularity, and periods only when given', () async {
      answer(trendJson());
      await ds.myTrend(TrendGranularity.month);
      verify(
        () => dio.get(
          ApiEndpoints.myStatsTrend,
          queryParameters: {'granularity': 'month'},
        ),
      ).called(1);
      await ds.myTrend(TrendGranularity.week, periods: 4);
      verify(
        () => dio.get(
          ApiEndpoints.myStatsTrend,
          queryParameters: {'granularity': 'week', 'periods': 4},
        ),
      ).called(1);
    });

    test('group routes hit the right paths', () async {
      answer(overviewJson());
      await ds.groupOverview('g1', from: '2026-10-01');
      verify(
        () => dio.get(
          ApiEndpoints.groupStatsOverview('g1'),
          queryParameters: {'from': '2026-10-01'},
        ),
      ).called(1);

      answer(membersJson());
      await ds.groupMembers('g1');
      verify(
        () =>
            dio.get(ApiEndpoints.groupStatsMembers('g1'), queryParameters: {}),
      ).called(1);

      answer(memberDetailJson());
      await ds.memberDetail('g1', 'u2');
      verify(
        () => dio.get(
          ApiEndpoints.groupStatsMember('g1', 'u2'),
          queryParameters: {},
        ),
      ).called(1);

      answer(attentionJson());
      await ds.attention('g1', inactiveDays: 5);
      verify(
        () => dio.get(
          ApiEndpoints.groupStatsAttention('g1'),
          queryParameters: {'inactiveDays': 5},
        ),
      ).called(1);
    });

    test('the paths are what the API reference documents', () {
      expect(ApiEndpoints.myStatsSummary, endsWith('/users/me/stats/summary'));
      expect(
        ApiEndpoints.groupStatsOverview('g1'),
        endsWith('/groups/g1/stats/overview'),
      );
      expect(
        ApiEndpoints.groupStatsMember('g1', 'u2'),
        endsWith('/groups/g1/stats/members/u2'),
      );
      expect(
        ApiEndpoints.groupStatsAttention('g1'),
        endsWith('/groups/g1/stats/attention'),
      );
    });

    test('a 403 keeps the server message', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(_http(403, 'Only the admin can see this'));
      await expectLater(
        ds.attention('g1'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 403)
              .having(
                (e) => e.message,
                'message',
                'Only the admin can see this',
              ),
        ),
      );
    });

    test('a connection error is a NetworkException', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(dioError());
      await expectLater(ds.myDaily(), throwsA(isA<NetworkException>()));
    });

    test('a body of the wrong shape is a ServerException', () async {
      answer('nope');
      await expectLater(ds.mySummary(), throwsA(isA<ServerException>()));
      await expectLater(ds.groupMembers('g1'), throwsA(isA<ServerException>()));
    });

    test('success:false is a ServerException', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => okResponse({'success': false}));
      await expectLater(
        ds.myTrend(TrendGranularity.week),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('repository', () {
    late _MockRemote remote;
    late StatisticsRepositoryImpl repo;
    setUp(() {
      remote = _MockRemote();
      repo = StatisticsRepositoryImpl(remote);
    });

    test('passes data through as Success', () async {
      when(
        () => remote.groupMembers('g1', from: any(named: 'from')),
      ).thenAnswer((_) async => groupMembersFromJson(membersJson()));
      final r = await repo.groupMembers('g1');
      expect((r as Success<List<GroupMemberStat>>).data, hasLength(3));
    });

    test('maps a network error', () async {
      when(
        () => remote.myDaily(from: any(named: 'from')),
      ).thenThrow(const NetworkException());
      expect(((await repo.myDaily()) as Error).failure, isA<NetworkFailure>());
    });

    test('keeps the server message on a rejection', () async {
      when(
        () => remote.attention('g1', inactiveDays: any(named: 'inactiveDays')),
      ).thenThrow(const ServerException('Admins only', 403));
      final f = ((await repo.attention('g1')) as Error).failure;
      expect(f, isA<ServerFailure>());
      expect(f.message, 'Admins only');
    });

    test('maps anything unexpected', () async {
      when(
        () => remote.mySummary(from: any(named: 'from')),
      ).thenThrow(StateError('boom'));
      expect(
        ((await repo.mySummary()) as Error).failure,
        isA<UnexpectedFailure>(),
      );
    });

    test('attention never sends an out-of-range threshold', () async {
      for (final bad in [0, 31, -2]) {
        expect(await repo.attention('g1', inactiveDays: bad), isA<Error>());
      }
      verifyNever(
        () => remote.attention(any(), inactiveDays: any(named: 'inactiveDays')),
      );
    });
  });
}
