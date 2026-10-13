import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';

const _group = {
  'id': '9bc58689',
  'name': 'Namaz Family Group',
  'description': 'Daily recitation group',
  'inviteCode': 'JbwjmgCS',
  'isInviteActive': true,
  'createdBy': 'u1',
  'createdAt': '2026-10-06T07:13:41.341Z',
  'updatedAt': '2026-10-06T07:13:41.341Z',
};

DioException _http(int status, Object body) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/'),
  ),
);

void main() {
  group('detail / update / delete', groupDetailTests);
  late MockDio dio;
  late GroupsRemoteDataSourceImpl ds;
  setUp(() {
    dio = MockDio();
    ds = GroupsRemoteDataSourceImpl(dio);
  });

  test('getGroups parses the list incl. role', () async {
    stubGet(dio, {
      'success': true,
      'data': [
        {..._group, 'role': 'admin'},
      ],
    });
    final r = await ds.getGroups();
    expect(r.single.role, 'admin');
    expect(r.single.inviteCode, 'JbwjmgCS');
    verify(() => dio.get(ApiEndpoints.groups)).called(1);
  });

  test('getGroups empty list', () async {
    stubGet(dio, {'success': true, 'data': []});
    expect(await ds.getGroups(), isEmpty);
  });

  test('createGroup posts name + description and parses the group', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse({'success': true, 'data': _group}, status: 201),
    );
    final g = await ds.createGroup(
      name: 'Namaz Family Group',
      description: 'Daily recitation group',
    );
    expect(g.id, '9bc58689');
    expect(g.role, isNull);
    verify(
      () => dio.post(
        ApiEndpoints.groups,
        data: {
          'name': 'Namaz Family Group',
          'description': 'Daily recitation group',
        },
      ),
    ).called(1);
  });

  test('empty description is omitted from the body', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse({
        'success': true,
        'data': {..._group, 'description': null},
      }),
    );
    final g = await ds.createGroup(name: 'Solo', description: '');
    expect(g.description, isNull);
    verify(
      () => dio.post(ApiEndpoints.groups, data: {'name': 'Solo'}),
    ).called(1);
  });

  test('validation errors surface joined messages', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
      _http(400, {
        'message': ['name should not be empty', 'name must be a string'],
      }),
    );
    expect(
      () => ds.createGroup(name: ''),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'name should not be empty\nname must be a string',
        ),
      ),
    );
  });

  test('connection errors and malformed bodies are mapped', () async {
    stubGetThrows(dio);
    expect(() => ds.getGroups(), throwsA(isA<NetworkException>()));
    stubGet(dio, {'success': true, 'data': 'oops'});
    expect(() => ds.getGroups(), throwsA(isA<ServerException>()));
  });
}

void groupDetailTests() {
  late MockDio dio;
  late GroupsRemoteDataSourceImpl ds;
  setUp(() {
    dio = MockDio();
    ds = GroupsRemoteDataSourceImpl(dio);
  });

  test('getGroupDetail hits /groups/{id} and parses members', () async {
    stubGet(dio, {
      'success': true,
      'data': {
        ..._group,
        'members': [
          {
            'userId': 'u1',
            'name': 'alee',
            'email': 'a@b.c',
            'role': 'admin',
            'joinedAt': '2026-10-06T07:13:41.343Z',
          },
        ],
      },
    });
    final d = await ds.getGroupDetail('9bc58689');
    expect(d.members.single.role, 'admin');
    expect(d.members.single.joinedAt, isNotNull);
    expect(d.toEntity().memberCount, 1);
    verify(() => dio.get(ApiEndpoints.group('9bc58689'))).called(1);
  });

  test('404 Group not found is surfaced', () async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 404,
          data: {'message': 'Group not found'},
          requestOptions: RequestOptions(path: '/'),
        ),
      ),
    );
    expect(
      () => ds.getGroupDetail('x'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Group not found',
        ),
      ),
    );
  });

  test('updateGroup PATCHes name + description', () async {
    when(() => dio.patch(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse({
        'success': true,
        'data': {..._group, 'name': 'Office Namaz Group'},
      }),
    );
    final g = await ds.updateGroup(
      'g',
      name: 'Office Namaz Group',
      description: 'd',
    );
    expect(g.name, 'Office Namaz Group');
    verify(
      () => dio.patch(
        ApiEndpoints.group('g'),
        data: {'name': 'Office Namaz Group', 'description': 'd'},
      ),
    ).called(1);
  });

  test('deleteGroup sends DELETE', () async {
    when(() => dio.delete(any())).thenAnswer(
      (_) async => okResponse({
        'success': true,
        'data': {'message': 'Group deleted'},
      }),
    );
    await ds.deleteGroup('g');
    verify(() => dio.delete(ApiEndpoints.group('g'))).called(1);
  });

  test('getInvite GETs /groups/{id}/invite with the given id', () async {
    stubGet(dio, {
      'success': true,
      'data': {
        'token': 'HL9hE90a0igcw7o1nkBhiA',
        'url':
            'https://deencompanion.dgexpense.com/invite/HL9hE90a0igcw7o1nkBhiA',
      },
    });
    final r = await ds.getInvite('abc');
    expect(r.token, 'HL9hE90a0igcw7o1nkBhiA');
    expect(r.url, endsWith('/invite/HL9hE90a0igcw7o1nkBhiA'));
    verify(() => dio.get(ApiEndpoints.groupInvite('abc'))).called(1);
    expect(
      ApiEndpoints.groupInvite('abc'),
      'https://deencompanion.dgexpense.com/api/groups/abc/invite',
    );
  });

  test(
    'resetInvite POSTs /groups/{id}/invite/reset and returns the new link',
    () async {
      when(() => dio.post(any())).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': {
            'token': '6ltDPk9wRl-STtTq05sdOA',
            'url': 'https://x/invite/6ltDPk9wRl-STtTq05sdOA',
          },
        }),
      );
      final r = await ds.resetInvite('abc');
      expect(r.token, '6ltDPk9wRl-STtTq05sdOA');
      verify(() => dio.post(ApiEndpoints.groupInviteReset('abc'))).called(1);
      expect(
        ApiEndpoints.groupInviteReset('abc'),
        'https://deencompanion.dgexpense.com/api/groups/abc/invite/reset',
      );
    },
  );

  test('invite 404 / malformed bodies are mapped', () async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 404,
          data: {'message': 'Group not found'},
          requestOptions: RequestOptions(path: '/'),
        ),
      ),
    );
    expect(
      () => ds.getInvite('x'),
      throwsA(
        isA<ServerException>().having((e) => e.message, 'm', 'Group not found'),
      ),
    );
    stubGet(dio, {
      'success': true,
      'data': {'token': 1},
    });
    expect(() => ds.getInvite('x'), throwsA(isA<ServerException>()));
  });

  test(
    'getInvitePreview GETs /invites/{token}; isMember absent for guests',
    () async {
      stubGet(dio, {
        'success': true,
        'data': {
          'groupName': 'Family Prayers',
          'description': 'x',
          'memberCount': 5,
        },
      });
      final p = await ds.getInvitePreview('tok_1-A');
      expect(p.groupName, 'Family Prayers');
      expect(p.memberCount, 5);
      expect(p.isMember, isFalse);
      expect(p.groupId, isNull);
      verify(() => dio.get(ApiEndpoints.invitePreview('tok_1-A'))).called(1);
      expect(
        ApiEndpoints.invitePreview('tok_1-A'),
        'https://deencompanion.dgexpense.com/api/invites/tok_1-A',
      );
    },
  );

  test('preview for a member carries isMember + groupId', () async {
    stubGet(dio, {
      'success': true,
      'data': {
        'groupName': 'G',
        'description': 'x',
        'memberCount': 1,
        'isMember': true,
        'groupId': 'gid',
      },
    });
    final p = await ds.getInvitePreview('t');
    expect(p.isMember, isTrue);
    expect(p.groupId, 'gid');
  });

  test('joinWithInvite POSTs /invites/{token}/join', () async {
    when(() => dio.post(any())).thenAnswer(
      (_) async => okResponse({
        'success': true,
        'data': {'groupId': '9bc58689', 'alreadyMember': true},
      }),
    );
    final r = await ds.joinWithInvite('tok');
    expect(r.groupId, '9bc58689');
    expect(r.alreadyMember, isTrue);
    verify(() => dio.post(ApiEndpoints.inviteJoin('tok'))).called(1);
    expect(
      ApiEndpoints.inviteJoin('tok'),
      'https://deencompanion.dgexpense.com/api/invites/tok/join',
    );
  });

  test('invalid/reset invite (404) message is surfaced', () async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 404,
          data: {'message': 'This invite link is invalid or has been reset'},
          requestOptions: RequestOptions(path: '/'),
        ),
      ),
    );
    expect(
      () => ds.getInvitePreview('x'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'm',
          'This invite link is invalid or has been reset',
        ),
      ),
    );
  });

  test('removeMember DELETEs /groups/{id}/members/{userId}', () async {
    when(() => dio.delete(any())).thenAnswer(
      (_) async => okResponse({
        'success': true,
        'data': {'message': 'Member removed'},
      }),
    );
    await ds.removeMember('gid', 'uid');
    verify(() => dio.delete(ApiEndpoints.groupMember('gid', 'uid'))).called(1);
    expect(
      ApiEndpoints.groupMember('gid', 'uid'),
      'https://deencompanion.dgexpense.com/api/groups/gid/members/uid',
    );
  });

  test('leaveGroup POSTs /groups/{id}/leave (201 is fine)', () async {
    when(() => dio.post(any())).thenAnswer(
      (_) async => okResponse({
        'success': true,
        'data': {'message': 'You left the group'},
      }, status: 201),
    );
    await ds.leaveGroup('gid');
    verify(() => dio.post(ApiEndpoints.groupLeave('gid'))).called(1);
    expect(
      ApiEndpoints.groupLeave('gid'),
      'https://deencompanion.dgexpense.com/api/groups/gid/leave',
    );
  });

  test('403 / 400 errors from member removal are surfaced', () async {
    when(() => dio.delete(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 403,
          data: {'message': 'Only the group admin can do this'},
          requestOptions: RequestOptions(path: '/'),
        ),
      ),
    );
    expect(
      () => ds.removeMember('g', 'u'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'm',
          'Only the group admin can do this',
        ),
      ),
    );
  });
}
