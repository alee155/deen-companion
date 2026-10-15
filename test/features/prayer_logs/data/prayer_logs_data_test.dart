import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_log_models.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_remote_datasource.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_repository_impl.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_support/dio_test_support.dart';

Map<String, dynamic> _log({
  String id = 'a1b2',
  String prayer = 'asr',
  String date = '2026-10-13',
  String status = 'on_time',
  Object? snapUrl = 'https://res.cloudinary.com/x?sig=1',
}) => {
  'id': id,
  'prayer': prayer,
  'date': date,
  'status': status,
  'points': 5,
  'snapUrl': snapUrl,
  'windowStartsAt': '2026-10-13T10:05:00.000Z',
  'windowEndsAt': '2026-10-13T12:25:00.000Z',
  'loggedAt': '2026-10-13T10:30:00.000Z',
};

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
  group('models', () {
    test('log parses, with a string id and a nullable snap', () {
      final log = prayerLogFromJson(_log(snapUrl: null));
      expect(log.id, 'a1b2');
      expect(log.prayer, PrayerName.asr);
      expect(log.points, 5);
      expect(log.snapUrl, isNull);
      expect(log.status, PrayerLogStatus.onTime);
      expect(log.canUndo(DateTime.utc(2026, 10, 13, 12, 0)), isTrue);
      expect(log.canUndo(DateTime.utc(2026, 10, 13, 12, 25)), isFalse);
    });

    test('unknown status does not fail', () {
      expect(
        prayerLogFromJson(_log(status: 'late')).status,
        PrayerLogStatus.late,
      );
      expect(
        prayerLogFromJson(_log(status: 'wat')).status,
        PrayerLogStatus.unknown,
      );
    });

    test('current state carries date, logged and logId', () {
      final s = currentPrayerStateFromJson({
        'now': '2026-10-12T20:00:00.000Z',
        'current': {
          'prayer': 'isha',
          'date': '2026-10-12',
          'startsAt': '2026-10-12T14:00:00.000Z',
          'endsAt': '2026-10-13T00:00:00.000Z',
          'logged': true,
          'logId': 'uuid-1',
        },
        'next': {'prayer': 'fajr', 'startsAt': '2026-10-13T00:00:00.000Z'},
      });
      expect(s.current!.date, '2026-10-12');
      expect(s.current!.logged, isTrue);
      expect(s.current!.logId, 'uuid-1');
      expect(s.next!.prayer, PrayerName.fajr);
      expect(s.isNotSynced, isFalse);
    });

    test('both null means not synced; closed window keeps next', () {
      final none = currentPrayerStateFromJson({
        'now': '2026-10-13T10:00:00.000Z',
        'current': null,
        'next': null,
      });
      expect(none.isNotSynced, isTrue);
      final between = currentPrayerStateFromJson({
        'now': '2026-10-13T10:00:00.000Z',
        'current': null,
        'next': {'prayer': 'asr', 'startsAt': '2026-10-13T10:05:00.000Z'},
      });
      expect(between.isNotSynced, isFalse);
      expect(between.current, isNull);
    });

    test('groupLogsByDate groups and orders Fajr to Isha', () {
      final grouped = groupLogsByDate([
        prayerLogFromJson(_log(id: '1', prayer: 'isha')),
        prayerLogFromJson(_log(id: '2', prayer: 'fajr')),
        prayerLogFromJson(_log(id: '3', prayer: 'dhuhr', date: '2026-10-12')),
      ]);
      expect(grouped.keys, ['2026-10-13', '2026-10-12']);
      expect(grouped['2026-10-13']!.map((l) => l.prayer), [
        PrayerName.fajr,
        PrayerName.isha,
      ]);
    });
  });

  group('datasource', () {
    late MockDio dio;
    late PrayerLogsRemoteDataSourceImpl ds;
    setUp(() {
      dio = MockDio();
      ds = PrayerLogsRemoteDataSourceImpl(dio);
    });

    test(
      'getLogs without a date sends no query (server decides today)',
      () async {
        when(
          () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
        ).thenAnswer(
          (_) async => okResponse({
            'success': true,
            'data': [_log()],
          }),
        );
        final logs = await ds.getLogs();
        expect(logs, hasLength(1));
        verify(
          () => dio.get(ApiEndpoints.prayerLogs, queryParameters: null),
        ).called(1);
      },
    );

    test('getLogs with a date and an empty list', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': []}));
      expect(await ds.getLogs(date: '2026-10-12'), isEmpty);
      verify(
        () => dio.get(
          ApiEndpoints.prayerLogs,
          queryParameters: {'date': '2026-10-12'},
        ),
      ).called(1);
    });

    test('getLogsRange passes from and to', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': []}));
      await ds.getLogsRange(from: '2026-10-01', to: '2026-10-31');
      verify(
        () => dio.get(
          ApiEndpoints.prayerLogsRange,
          queryParameters: {'from': '2026-10-01', 'to': '2026-10-31'},
        ),
      ).called(1);
    });

    test('getCurrent parses the data object', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': {
            'now': '2026-10-13T10:00:00.000Z',
            'current': null,
            'next': null,
          },
        }),
      );
      expect((await ds.getCurrent()).isNotSynced, isTrue);
    });

    test('a malformed body becomes a ServerException', () async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': 'nope'}));
      expect(ds.getCurrent(), throwsA(isA<ServerException>()));
    });

    test('error body keeps status, code and data', () async {
      when(() => dio.get(any())).thenThrow(
        _http(422, {
          'success': false,
          'statusCode': 422,
          'message': 'No active prayer window',
          'code': 'NO_ACTIVE_PRAYER_WINDOW',
          'data': {'nextPrayer': 'asr', 'startsAt': 'x'},
        }),
      );
      await expectLater(
        ds.getCurrent(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 422)
              .having((e) => e.code, 'code', 'NO_ACTIVE_PRAYER_WINDOW')
              .having((e) => e.data!['nextPrayer'], 'data', 'asr'),
        ),
      );
    });
  });

  group('repository', () {
    late MockDio dio;
    late PrayerLogsRepositoryImpl repo;
    setUp(() {
      dio = MockDio();
      repo = PrayerLogsRepositoryImpl(PrayerLogsRemoteDataSourceImpl(dio));
    });

    test('server error becomes PrayerLogFailure with its code', () async {
      when(() => dio.get(any())).thenThrow(
        _http(409, {
          'success': false,
          'message': 'Times not synced',
          'code': 'PRAYER_TIMES_NOT_SYNCED',
        }),
      );
      final r = await repo.getCurrent();
      final f = (r as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.timesNotSynced);
      expect(f.message, 'Times not synced');
      expect(f.statusCode, 409);
    });

    test('connection errors become NetworkFailure', () async {
      when(() => dio.get(any())).thenThrow(dioError());
      expect(
        ((await repo.getCurrent()) as Error).failure,
        isA<NetworkFailure>(),
      );
    });
  });
}
