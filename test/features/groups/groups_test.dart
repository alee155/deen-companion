import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:deen_companion/features/groups/data/models/group_model.dart';
import 'package:deen_companion/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/domain/entities/group_invite.dart';
import 'package:deen_companion/features/groups/domain/entities/invite_preview.dart';
import 'package:deen_companion/features/groups/domain/invite_link.dart';
import 'package:deen_companion/features/groups/domain/repositories/groups_repository.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _newGroup = NewGroup(
  name: 'Test Circle',
  description: 'desc',
  imagePath: '/tmp/x.png',
);

Map<String, dynamic> _json({
  String id = 'g1',
  String name = 'Namaz Family Group',
  String? description = 'Daily recitation group',
  String? role,
}) => {
  'id': id,
  'name': name,
  'description': description,
  'inviteCode': 'JbwjmgCS',
  'isInviteActive': true,
  'createdBy': 'u1',
  'createdAt': '2026-10-06T07:13:41.341Z',
  'updatedAt': '2026-10-06T07:13:42.341Z',
  'role': ?role,
};

class FakeRemote implements GroupsRemoteDataSource {
  List<GroupModel> groups;
  Object? error;
  int getCalls = 0;
  ({String name, String? description})? lastCreate;
  String? lastCreateImage;
  String? lastUpdateImage;
  String? removedAvatarOf;
  GroupDetailModel? detail;
  ({String id, String name, String description})? lastUpdate;
  String? deletedId;
  final Map<String, int> inviteVersion = {};
  final List<String> inviteCalls = [];
  final Map<String, InvitePreviewModel> previews = {};
  final List<String> joined = [];
  final List<({String group, String user})> removed = [];
  final List<String> left = [];

  FakeRemote([List<GroupModel>? groups]) : groups = groups ?? [];

  @override
  Future<List<GroupModel>> getGroups() async {
    getCalls++;
    if (error != null) throw error!;
    return groups;
  }

  @override
  Future<GroupModel> createGroup({
    required String name,
    String? description,
    String? imagePath,
  }) async {
    if (error != null) throw error!;
    lastCreate = (name: name, description: description);
    lastCreateImage = imagePath;
    final m = GroupModel.fromJson(
      _json(id: 'new', name: name, description: description),
    );
    groups = [m, ...groups];
    return m;
  }

  @override
  Future<GroupDetailModel> getGroupDetail(String groupId) async {
    if (error != null) throw error!;
    return _detail(groupId);
  }

  @override
  Future<GroupModel> updateGroup(
    String groupId, {
    required String name,
    required String description,
    String? imagePath,
  }) async {
    if (error != null) throw error!;
    lastUpdate = (id: groupId, name: name, description: description);
    lastUpdateImage = imagePath;
    return GroupModel.fromJson(
      _json(id: groupId, name: name, description: description),
    );
  }

  GroupInviteModel _invite(String id) {
    final t = 'tok-$id-${inviteVersion[id] ?? 0}';
    return GroupInviteModel(token: t, url: 'https://x.test/invite/$t');
  }

  @override
  Future<void> removeAvatar(String groupId) async {
    if (error != null) throw error!;
    removedAvatarOf = groupId;
  }

  @override
  Future<GroupInviteModel> getInvite(String groupId) async {
    inviteCalls.add('get:$groupId');
    if (error != null) throw error!;
    return _invite(groupId);
  }

  @override
  Future<GroupInviteModel> resetInvite(String groupId) async {
    inviteCalls.add('reset:$groupId');
    if (error != null) throw error!;
    inviteVersion[groupId] = (inviteVersion[groupId] ?? 0) + 1;
    return _invite(groupId);
  }

  @override
  Future<InvitePreviewModel> getInvitePreview(String token) async {
    if (error != null) throw error!;
    return previews[token] ??
        (throw const ServerException(
          'This invite link is invalid or has been reset',
        ));
  }

  @override
  Future<JoinResultModel> joinWithInvite(String token) async {
    if (error != null) throw error!;
    if (!previews.containsKey(token)) {
      throw const ServerException(
        'This invite link is invalid or has been reset',
      );
    }
    final already = joined.contains(token);
    joined.add(token);
    return JoinResultModel(groupId: 'joined-$token', alreadyMember: already);
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    if (error != null) throw error!;
    removed.add((group: groupId, user: userId));
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    if (error != null) throw error!;
    left.add(groupId);
    groups = groups.where((g) => g.id != groupId).toList();
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    if (error != null) throw error!;
    deletedId = groupId;
    groups = groups.where((g) => g.id != groupId).toList();
  }
}

extension on FakeRemote {
  GroupDetailModel _detail(String id) =>
      detail ??
      GroupDetailModel.fromJson({
        ..._json(id: id),
        'members': [
          {
            'userId': 'u1',
            'name': 'Ali',
            'email': 'a@b.c',
            'role': 'admin',
            'joinedAt': '2026-10-06T07:13:41.343Z',
          },
          {
            'userId': 'u2',
            'name': 'Sara',
            'email': 's@b.c',
            'role': 'member',
            'joinedAt': '2026-10-07T07:13:41.343Z',
          },
        ],
      });
}

class _FixedSession extends AuthSessionNotifier {
  final AuthSession session;
  _FixedSession(this.session);
  @override
  AuthSession build() => session;
}

const _signedIn = AuthSession(userId: 'u1', email: 'a@b.c', name: 'Ali');

class FailingRepo implements GroupsRepository {
  @override
  Future<Result<Group>> createGroup(NewGroup input) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<GroupDetail>> getGroupDetail(String groupId) async =>
      const Error(NotFoundFailure());
  @override
  Future<Result<Group>> updateGroup(
    String groupId, {
    required String name,
    required String description,
    String? imagePath,
  }) async => const Error(ServerFailure('nope'));
  @override
  Future<Result<void>> removeGroupImage(String groupId) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<void>> deleteGroup(String groupId) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<void>> removeMember(String groupId, String userId) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<void>> leaveGroup(String groupId) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<InvitePreview>> previewInvite(String token) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<JoinResult>> joinGroup(String token) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<GroupInvite>> getInvite(String groupId) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<GroupInvite>> resetInvite(String groupId) async =>
      const Error(ServerFailure('nope'));
  @override
  Future<Result<List<Group>>> getMyGroups() async =>
      const Error(UnexpectedFailure());
}

void main() {
  group('GroupModel / Group entity', () {
    test('maps every API field, including ones the UI does not use yet', () {
      final g = GroupModel.fromJson(_json(role: 'admin')).toEntity();
      expect(g.id, 'g1');
      expect(g.name, 'Namaz Family Group');
      expect(g.description, 'Daily recitation group');
      expect(g.inviteCode, 'JbwjmgCS');
      expect(g.isInviteActive, isTrue);
      expect(g.createdBy, 'u1');
      expect(g.createdAt, DateTime.utc(2026, 10, 6, 7, 13, 41, 341));
      expect(g.updatedAt, DateTime.utc(2026, 10, 6, 7, 13, 42, 341));
      expect(g.role, GroupRole.admin);
      expect(g.isOwner, isTrue);
    });

    test('null description becomes empty text', () {
      expect(
        GroupModel.fromJson(_json(description: null)).toEntity().description,
        '',
      );
    });

    test('missing role: member by default, fallback when given', () {
      final m = GroupModel.fromJson(_json());
      expect(m.toEntity().role, GroupRole.member);
      expect(m.toEntity().isOwner, isFalse);
      expect(m.toEntity(fallbackRole: GroupRole.admin).role, GroupRole.admin);
    });

    test('unknown role falls back to member', () {
      expect(GroupRole.parse('moderator'), GroupRole.member);
      expect(GroupRole.parse(null), GroupRole.member);
    });

    test('isPrivate reflects privacy', () {
      expect(const Group(id: '1', name: 'a').isPrivate, isTrue);
      expect(
        const Group(id: '1', name: 'a', privacy: GroupPrivacy.public).isPrivate,
        isFalse,
      );
    });
  });

  group('InviteLink', () {
    test('extracts the token from an invite URL', () {
      expect(
        InviteLink.tokenFromUrl(
          'https://deencompanion.dgexpense.com/invite/h_7iTqMt6p_5o_oOzAwZyQ',
        ),
        'h_7iTqMt6p_5o_oOzAwZyQ',
      );
      expect(
        InviteLink.tokenFromUrl('https://x.test/invite/abc-DEF?utm=1'),
        'abc-DEF',
      );
    });

    test('rejects non-invite URLs', () {
      expect(InviteLink.tokenFromUrl('https://x.test/other/abc'), isNull);
      expect(InviteLink.tokenFromUrl('https://x.test/invite/'), isNull);
      expect(InviteLink.tokenFromUrl('not a url at all'), isNull);
    });

    test('routeFor builds the in-app path', () {
      expect(InviteLink.routeFor('a-b_c'), '/invite/a-b_c');
    });
  });

  group('GroupsRepositoryImpl', () {
    late FakeRemote remote;
    late GroupsRepositoryImpl repo;
    setUp(() {
      remote = FakeRemote([
        GroupModel.fromJson(_json(role: 'admin')),
        GroupModel.fromJson(_json(id: 'g2', name: 'Other', role: 'member')),
      ]);
      repo = GroupsRepositoryImpl(remote: remote);
    });

    test('getMyGroups maps API groups in order', () async {
      final groups = (await repo.getMyGroups() as Success<List<Group>>).data;
      expect(groups.map((g) => g.id), ['g1', 'g2']);
      expect(groups.map((g) => g.isOwner), [true, false]);
    });

    test('empty list is a success, not an error', () async {
      remote.groups = [];
      expect((await repo.getMyGroups() as Success<List<Group>>).data, isEmpty);
    });

    test(
      'createGroup sends only name + description; creator is admin',
      () async {
        final g = (await repo.createGroup(_newGroup) as Success<Group>).data;
        expect(remote.lastCreate, (name: 'Test Circle', description: 'desc'));
        expect(g.role, GroupRole.admin);
        expect(g.isOwner, isTrue);
        expect(g.inviteCode, 'JbwjmgCS');
      },
    );

    test('errors map to failures', () async {
      remote.error = const ServerException('Unauthorized');
      expect(
        ((await repo.getMyGroups()) as Error).failure.message,
        'Unauthorized',
      );
      remote.error = const NetworkException();
      expect(
        ((await repo.getMyGroups()) as Error).failure,
        isA<NetworkFailure>(),
      );
      remote.error = const ServerException('name should not be empty');
      final r = await repo.createGroup(_newGroup);
      expect((r as Error).failure.message, 'name should not be empty');
      remote.error = StateError('x');
      expect(
        ((await repo.getMyGroups()) as Error).failure,
        isA<UnexpectedFailure>(),
      );
    });

    test('getGroupDetail maps members and roles', () async {
      final d = (await repo.getGroupDetail('g1') as Success<GroupDetail>).data;
      expect(d.memberCount, 2);
      expect(d.members.first.role, GroupRole.admin);
      expect(d.members.first.joinedAt, isNotNull);
      expect(d.inviteCode, 'JbwjmgCS');
      expect(d.isAdmin('u1'), isTrue);
      expect(d.isAdmin('u2'), isFalse);
      expect(d.isAdmin('stranger'), isFalse);
    });

    test('getGroupDetail errors map (404 message surfaced)', () async {
      remote.error = const ServerException('Group not found');
      expect(
        ((await repo.getGroupDetail('x')) as Error).failure.message,
        'Group not found',
      );
    });

    test('updateGroup sends name + description', () async {
      final g =
          (await repo.updateGroup('g1', name: 'New', description: 'D')
                  as Success<Group>)
              .data;
      expect(remote.lastUpdate, (id: 'g1', name: 'New', description: 'D'));
      expect(g.name, 'New');
      expect(g.isOwner, isTrue);
    });

    test(
      'updateGroup / deleteGroup surface server errors (e.g. not admin)',
      () async {
        remote.error = const ServerException('Forbidden');
        expect(
          ((await repo.updateGroup('g1', name: 'n', description: '')) as Error)
              .failure
              .message,
          'Forbidden',
        );
        expect(
          ((await repo.deleteGroup('g1')) as Error).failure.message,
          'Forbidden',
        );
      },
    );

    test('deleteGroup calls the API', () async {
      expect(await repo.deleteGroup('g1'), isA<Success>());
      expect(remote.deletedId, 'g1');
    });

    test(
      'invite get/reset use the given group id and return the new link',
      () async {
        final a = (await repo.getInvite('g1') as Success<GroupInvite>).data;
        expect(a.token, 'tok-g1-0');
        final b = (await repo.resetInvite('g1') as Success<GroupInvite>).data;
        expect(b.token, 'tok-g1-1');
        expect(b.url, endsWith('/invite/tok-g1-1'));
        expect(remote.inviteCalls, ['get:g1', 'reset:g1']);
      },
    );

    test('invite errors surface the server message', () async {
      remote.error = const ServerException('Group not found');
      expect(
        ((await repo.getInvite('x')) as Error).failure.message,
        'Group not found',
      );
      expect(
        ((await repo.resetInvite('x')) as Error).failure.message,
        'Group not found',
      );
    });

    test('previewInvite / joinGroup map the API shapes', () async {
      remote.previews['T'] = const InvitePreviewModel(
        groupName: 'Family',
        description: null,
        memberCount: 5,
        isMember: false,
        groupId: null,
      );
      final p = (await repo.previewInvite('T') as Success<InvitePreview>).data;
      expect(p.groupName, 'Family');
      expect(p.description, '');
      expect(p.memberCount, 5);
      expect(p.isMember, isFalse);
      final j = (await repo.joinGroup('T') as Success<JoinResult>).data;
      expect(j.groupId, 'joined-T');
      expect(j.alreadyMember, isFalse);
      expect(
        (await repo.joinGroup('T') as Success<JoinResult>).data.alreadyMember,
        isTrue,
      );
    });

    test('bad/reset token surfaces the server message', () async {
      expect(
        ((await repo.previewInvite('nope')) as Error).failure.message,
        'This invite link is invalid or has been reset',
      );
      expect(
        ((await repo.joinGroup('nope')) as Error).failure.message,
        'This invite link is invalid or has been reset',
      );
    });

    test('removeMember / leaveGroup call the API with the right ids', () async {
      expect(await repo.removeMember('g1', 'u2'), isA<Success>());
      expect(remote.removed, [(group: 'g1', user: 'u2')]);
      expect(await repo.leaveGroup('g1'), isA<Success>());
      expect(remote.left, ['g1']);
    });

    test('member removal / leave errors surface the server message', () async {
      remote.error = const ServerException('Only the group admin can do this');
      expect(
        ((await repo.removeMember('g1', 'u2')) as Error).failure.message,
        'Only the group admin can do this',
      );
      remote.error = const ServerException(
        'You are not a member of this group',
      );
      expect(
        ((await repo.leaveGroup('g1')) as Error).failure.message,
        'You are not a member of this group',
      );
    });
  });

  group('providers', () {
    late FakeRemote remote;

    ProviderContainer make({
      GroupsRepository? repo,
      AuthSession session = _signedIn,
    }) {
      final c = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => _FixedSession(session)),
          if (repo != null)
            groupsRepositoryProvider.overrideWithValue(repo)
          else
            groupsRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => remote = FakeRemote());

    test('no groups -> empty list (drives the empty state)', () async {
      expect(await make().read(myGroupsProvider.future), isEmpty);
      expect(remote.getCalls, 1);
    });

    test('loads the user\'s groups from the API', () async {
      remote.groups = [GroupModel.fromJson(_json(role: 'admin'))];
      final groups = await make().read(myGroupsProvider.future);
      expect(groups.single.name, 'Namaz Family Group');
    });

    test('guests never hit the API and see no groups', () async {
      final c = make(session: const AuthSession.guest());
      expect(await c.read(myGroupsProvider.future), isEmpty);
      expect(remote.getCalls, 0);
    });

    test('create prepends the new group to the list', () async {
      remote.groups = [GroupModel.fromJson(_json(role: 'member'))];
      final c = make();
      await c.read(myGroupsProvider.future);
      final r = await c.read(myGroupsProvider.notifier).create(_newGroup);
      expect(r, isA<Success<Group>>());
      final groups = c.read(myGroupsProvider).value!;
      expect(groups.map((g) => g.name), ['Test Circle', 'Namaz Family Group']);
      expect(groups.first.isOwner, isTrue);
    });

    test(
      'failed create leaves the list untouched and returns the error',
      () async {
        final c = make();
        await c.read(myGroupsProvider.future);
        remote.error = const ServerException('boom');
        final r = await c.read(myGroupsProvider.notifier).create(_newGroup);
        expect(r, isA<Error<Group>>());
        expect(c.read(myGroupsProvider).value, isEmpty);
      },
    );

    test('ownedGroupsCountProvider counts admin groups', () async {
      remote.groups = [
        GroupModel.fromJson(_json(role: 'admin')),
        GroupModel.fromJson(_json(id: 'g2', role: 'member')),
      ];
      final c = make();
      await c.read(myGroupsProvider.future);
      expect(c.read(ownedGroupsCountProvider), 1);
      await c.read(myGroupsProvider.notifier).create(_newGroup);
      expect(c.read(ownedGroupsCountProvider), 2);
    });

    test('ownedGroupsCountProvider is 0 before data loads', () {
      expect(make().read(ownedGroupsCountProvider), 0);
    });

    test('update replaces the group in the list, keeping role', () async {
      remote.groups = [GroupModel.fromJson(_json(role: 'admin'))];
      final c = make();
      await c.read(myGroupsProvider.future);
      final r = await c
          .read(myGroupsProvider.notifier)
          .updateGroup('g1', name: 'Renamed', description: 'New desc');
      expect(r, isA<Success<Group>>());
      final g = c.read(myGroupsProvider).value!.single;
      expect(g.name, 'Renamed');
      expect(g.description, 'New desc');
      expect(g.isOwner, isTrue);
      expect(g.inviteCode, 'JbwjmgCS');
    });

    test('delete removes the group from the list', () async {
      remote.groups = [
        GroupModel.fromJson(_json(role: 'admin')),
        GroupModel.fromJson(_json(id: 'g2', role: 'admin')),
      ];
      final c = make();
      await c.read(myGroupsProvider.future);
      await c.read(myGroupsProvider.notifier).deleteGroup('g1');
      expect(c.read(myGroupsProvider).value!.map((g) => g.id), ['g2']);
    });

    test('failed delete keeps the list', () async {
      remote.groups = [GroupModel.fromJson(_json(role: 'admin'))];
      final c = make();
      await c.read(myGroupsProvider.future);
      remote.error = const ServerException('boom');
      final r = await c.read(myGroupsProvider.notifier).deleteGroup('g1');
      expect(r, isA<Error<void>>());
      expect(c.read(myGroupsProvider).value, hasLength(1));
    });

    test('groupDetailProvider loads members for the id', () async {
      final d = await make().read(groupDetailProvider('g1').future);
      expect(d.members.map((m) => m.userId), ['u1', 'u2']);
    });

    test(
      'GroupManageController: update ok refreshes, failure reports',
      () async {
        remote.groups = [GroupModel.fromJson(_json(role: 'admin'))];
        final c = make();
        await c.read(myGroupsProvider.future);
        final sub = c.listen(groupManageControllerProvider, (_, _) {});
        addTearDown(sub.close);
        final n = c.read(groupManageControllerProvider.notifier);
        expect(await n.update('g1', name: 'X', description: ''), isTrue);
        expect(c.read(groupManageControllerProvider).isBusy, isFalse);
        remote.error = const ServerException('Only admins can edit');
        expect(await n.update('g1', name: 'Y', description: ''), isFalse);
        expect(
          c.read(groupManageControllerProvider).errorMessage,
          'Only admins can edit',
        );
        expect(await n.delete('g1'), isFalse);
        expect(
          c.read(groupManageControllerProvider).errorMessage,
          'Only admins can edit',
        );
        remote.error = null;
        expect(await n.delete('g1'), isTrue);
        expect(c.read(myGroupsProvider).value, isEmpty);
      },
    );

    test('failure surfaces as AsyncError holding the Failure', () async {
      final c = make(repo: FailingRepo());
      await expectLater(
        c.read(myGroupsProvider.future),
        throwsA(isA<UnexpectedFailure>()),
      );
      await expectLater(
        c.read(groupDetailProvider('x').future),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
