import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/moderation/data/api_moderation_repository.dart';
import 'package:deen_companion/features/moderation/data/moderation_remote_datasource.dart';
import 'package:deen_companion/features/moderation/domain/entities/blocked_user.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_reason.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_target.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';
import '_moderation_support.dart';

DioException _http(int status, Map<String, dynamic> body) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/'),
  ),
);

Map<String, dynamic> _ok(Object? data) => {'success': true, 'data': data};

Failure _failureOf<T>(Result<T> r) => (r as Error<T>).failure;

void main() {
  group('BlockedUser', () {
    test('round-trips through JSON', () {
      final u = BlockedUser(
        userId: 'u1',
        name: 'Sara Ahmed',
        avatarUrl: 'https://x.test/a.png',
        blockedAt: DateTime.utc(2026, 10, 28, 9, 30),
      );
      expect(BlockedUser.fromJson(u.toJson()), u);
    });

    test('unusable records are skipped, not fatal', () {
      expect(BlockedUser.fromJson(null), isNull);
      expect(BlockedUser.fromJson('text'), isNull);
      expect(BlockedUser.fromJson({'name': 'no id'}), isNull);
      expect(BlockedUser.fromJson({'userId': ''}), isNull);
    });

    test('a record with only an id still loads', () {
      final u = BlockedUser.fromJson({'userId': 'u1'})!;
      expect(u.userId, 'u1');
      expect(u.name, '');
      expect(u.avatarUrl, isNull);
    });

    test('initials come from the first two words', () {
      expect(blocked('a', name: 'Sara Ahmed Khan').initials, 'SA');
      expect(blocked('a', name: 'omar').initials, 'O');
      expect(blocked('a', name: '').initials, '?');
    });
  });

  test('every reason has a stable name for the API', () {
    expect(ReportReason.values.map((r) => r.apiValue), [
      'inappropriate',
      'harassment',
      'spam',
      'impersonation',
      'other',
    ]);
  });

  group('ApiModerationRepository', () {
    late MockDio dio;
    late ApiModerationRepository repo;

    setUp(() {
      dio = MockDio();
      repo = ApiModerationRepository(ModerationRemoteDataSourceImpl(dio));
    });

    When<Future<Response<dynamic>>> post() =>
        when(() => dio.post(any(), data: any(named: 'data')));

    group('report', () {
      test('a person is reported by user id', () async {
        post().thenAnswer(
          (_) async => okResponse(
            _ok({'id': 'r1', 'status': 'open', 'duplicate': false}),
          ),
        );
        final r = await repo.report(
          target: const ReportUserTarget(userId: 'u9', userName: 'Sara'),
          reason: ReportReason.harassment,
          details: 'rude',
        );
        expect(r, isA<Success<void>>());
        verify(
          () => dio.post(
            ApiEndpoints.reports,
            data: {
              'targetType': 'user',
              'targetId': 'u9',
              'reason': 'harassment',
              'details': 'rude',
            },
          ),
        ).called(1);
      });

      test('a snap is reported by log id, with the group it was in', () async {
        post().thenAnswer(
          (_) async => okResponse(
            _ok({'id': 'r1', 'status': 'open', 'duplicate': false}),
          ),
        );
        await repo.report(
          target: const ReportSnapTarget(
            snapId: 'log-1',
            groupId: 'g1',
            userId: 'u9',
            userName: 'Sara',
          ),
          reason: ReportReason.inappropriate,
        );
        verify(
          () => dio.post(
            ApiEndpoints.reports,
            data: {
              'targetType': 'snap',
              'targetId': 'log-1',
              'reason': 'inappropriate',
              'groupId': 'g1',
            },
          ),
        ).called(1);
      });

      test('reporting the same thing again is a success', () async {
        post().thenAnswer(
          (_) async => okResponse(
            _ok({'id': 'r1', 'status': 'open', 'duplicate': true}),
          ),
        );
        final r = await repo.report(
          target: const ReportUserTarget(userId: 'u9', userName: 'Sara'),
          reason: ReportReason.spam,
        );
        expect(r, isA<Success<void>>());
      });

      test('the errors have plain wording', () async {
        Future<String> reportWith(DioException e) async {
          post().thenThrow(e);
          return _failureOf(
            await repo.report(
              target: const ReportUserTarget(userId: 'u9', userName: 'Sara'),
              reason: ReportReason.spam,
            ),
          ).message;
        }

        expect(
          await reportWith(
            _http(400, {
              'success': false,
              'message': 'x',
              'code': 'CANNOT_REPORT_SELF',
            }),
          ),
          'You can’t report yourself.',
        );
        expect(
          await reportWith(
            _http(404, {
              'success': false,
              'message': 'x',
              'code': 'SNAP_NOT_FOUND',
            }),
          ),
          'This snap is no longer available.',
        );
        expect(
          await reportWith(
            _http(404, {
              'success': false,
              'message': 'x',
              'code': 'USER_NOT_FOUND',
            }),
          ),
          'This person is no longer available.',
        );
        expect(
          await reportWith(
            _http(429, {'success': false, 'message': 'Too many requests'}),
          ),
          contains('Too many requests'),
        );
        expect(
          await reportWith(
            _http(400, {'success': false, 'message': 'reason is invalid'}),
          ),
          'reason is invalid',
        );
      });

      test('offline is a network failure', () async {
        post().thenThrow(dioError());
        final r = await repo.report(
          target: const ReportUserTarget(userId: 'u9', userName: 'Sara'),
          reason: ReportReason.spam,
        );
        expect(_failureOf(r), isA<NetworkFailure>());
      });
    });

    group('blocking', () {
      test('the list comes from the server, with names and dates', () async {
        when(() => dio.get(any())).thenAnswer(
          (_) async => okResponse(
            _ok([
              {
                'userId': 'a',
                'name': 'Ali',
                'blockedAt': '2026-11-02T10:00:00.000Z',
              },
              {'userId': 'b', 'name': 'Bilal', 'blockedAt': 'bad date'},
              {'name': 'no id'},
            ]),
          ),
        );
        final list =
            ((await repo.getBlockedUsers()) as Success<List<BlockedUser>>).data;
        // The record with no id is skipped; the bad date does not fail it.
        expect(list.map((b) => b.userId), ['a', 'b']);
        expect(list.first.name, 'Ali');
        expect(list.first.blockedAt, DateTime.utc(2026, 11, 2, 10));
        verify(() => dio.get(ApiEndpoints.blocks)).called(1);
      });

      test('block posts the user id', () async {
        post().thenAnswer(
          (_) async => okResponse(
            _ok({
              'userId': 'a',
              'name': 'Ali',
              'blockedAt': '2026-11-02T10:00:00.000Z',
            }),
          ),
        );
        expect(await repo.blockUser(blocked('a')), isA<Success<void>>());
        verify(
          () => dio.post(ApiEndpoints.blocks, data: {'userId': 'a'}),
        ).called(1);
      });

      test('unblock deletes by user id', () async {
        when(() => dio.delete(any())).thenAnswer(
          (_) async => okResponse(_ok({'userId': 'a', 'blocked': false})),
        );
        expect(await repo.unblockUser('a'), isA<Success<void>>());
        verify(() => dio.delete(ApiEndpoints.block('a'))).called(1);
      });

      test('blocking yourself has its own message', () async {
        post().thenThrow(
          _http(400, {
            'success': false,
            'message': 'x',
            'code': 'CANNOT_BLOCK_SELF',
          }),
        );
        expect(
          _failureOf(await repo.blockUser(blocked('me'))).message,
          'You can’t block yourself.',
        );
      });

      test('a failure leaves a message, never throws', () async {
        when(() => dio.get(any())).thenThrow(dioError());
        expect(_failureOf(await repo.getBlockedUsers()), isA<NetworkFailure>());
        when(
          () => dio.delete(any()),
        ).thenThrow(_http(500, {'success': false, 'message': 'Server broke'}));
        expect(_failureOf(await repo.unblockUser('a')).message, 'Server broke');
      });
    });
  });

  group('ReportTarget', () {
    test('a snap target names its snap and its sender', () {
      const t = ReportSnapTarget(
        snapId: 's1',
        groupId: 'g1',
        userId: 'u1',
        userName: 'Sara',
      );
      expect(t.snapId, 's1');
      expect(t.userId, 'u1');
      expect(
        t,
        const ReportSnapTarget(
          snapId: 's1',
          groupId: 'g1',
          userId: 'u1',
          userName: 'Sara',
        ),
      );
      expect(
        t,
        isNot(
          const ReportSnapTarget(
            snapId: 's2',
            groupId: 'g1',
            userId: 'u1',
            userName: 'Sara',
          ),
        ),
      );
    });

    test('a user target is not equal to a snap target', () {
      expect(
        const ReportUserTarget(userId: 'u1', userName: 'Sara'),
        isNot(
          const ReportSnapTarget(
            snapId: 's',
            groupId: 'g1',
            userId: 'u1',
            userName: 'Sara',
          ),
        ),
      );
    });
  });

  test('a snap target in another group is a different report', () {
    expect(
      const ReportSnapTarget(
        snapId: 's1',
        groupId: 'g1',
        userId: 'u1',
        userName: 'Sara',
      ),
      isNot(
        const ReportSnapTarget(
          snapId: 's1',
          groupId: 'g2',
          userId: 'u1',
          userName: 'Sara',
        ),
      ),
    );
  });
}
