import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_remote_datasource.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_repository_impl.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_support/dio_test_support.dart';

Map<String, dynamic> _log(String prayer, int points) => {
  'id': 'id-$prayer',
  'prayer': prayer,
  'date': '2026-10-13',
  'status': 'on_time',
  'points': points,
  'snapUrl': null,
  'windowStartsAt': '2026-10-13T00:00:00.000Z',
  'windowEndsAt': '2026-10-13T01:00:00.000Z',
  'loggedAt': '2026-10-13T00:30:00.000Z',
};

void main() {
  late MockDio dio;
  late PrayerLogsRepositoryImpl repo;

  setUp(() {
    dio = MockDio();
    repo = PrayerLogsRepositoryImpl(PrayerLogsRemoteDataSourceImpl(dio));
  });

  void stubFeed(Object data) => when(
    () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
  ).thenAnswer((_) async => okResponse({'success': true, 'data': data}));

  test('parses members, roles and their logs; no email needed', () async {
    stubFeed([
      {
        'userId': 'u1',
        'name': 'Ali',
        'role': 'admin',
        'logs': [_log('fajr', 10), _log('dhuhr', 5)],
      },
      {'userId': 'u2', 'name': 'Sara', 'role': 'member', 'logs': []},
      {'userId': 'u3', 'name': '  ', 'role': 'member', 'logs': []},
    ]);
    final feed =
        (await repo.getGroupPrayers('g1', date: '2026-10-13') as Success).data;
    expect(feed, hasLength(3));
    final ali = feed.first;
    expect(ali.isAdmin, isTrue);
    expect(ali.role, GroupRole.admin);
    expect(ali.loggedCount, 2);
    expect(ali.totalPoints, 15);
    expect(ali.logFor(PrayerName.fajr)!.id, 'id-fajr');
    expect(ali.logFor(PrayerName.isha), isNull);
    expect(feed[1].loggedCount, 0);
    expect(feed[2].displayName, 'Member');
    expect(feed[2].initials, 'M');
    verify(
      () => dio.get(
        ApiEndpoints.groupPrayers('g1'),
        queryParameters: {'date': '2026-10-13'},
      ),
    ).called(1);
  });

  test('no date means the caller\'s today (no query sent)', () async {
    stubFeed([]);
    await repo.getGroupPrayers('g1');
    verify(
      () => dio.get(ApiEndpoints.groupPrayers('g1'), queryParameters: null),
    ).called(1);
  });

  test('403 for a non-member is recognised', () async {
    when(
      () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 403,
          data: {'success': false, 'message': 'Not a member'},
          requestOptions: RequestOptions(path: '/'),
        ),
      ),
    );
    final f =
        (await repo.getGroupPrayers('g1') as Error).failure as PrayerLogFailure;
    expect(f.code, PrayerLogErrorCode.notGroupMember);
    expect(f.message, 'Not a member');
  });
}
