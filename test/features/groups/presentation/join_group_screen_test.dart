import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:deen_companion/features/groups/data/models/group_model.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/join_group_screen.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Session extends AuthSessionNotifier {
  final AuthSession s;
  _Session(this.s);
  @override
  AuthSession build() => s;
}

class _Remote implements GroupsRemoteDataSource {
  InvitePreviewModel? preview;
  Object? previewError;
  Object? joinError;
  final joins = <String>[];

  @override
  Future<InvitePreviewModel> getInvitePreview(String token) async {
    if (previewError != null) throw previewError!;
    return preview!;
  }

  @override
  Future<JoinResultModel> joinWithInvite(String token) async {
    if (joinError != null) throw joinError!;
    joins.add(token);
    return const JoinResultModel(groupId: 'gid-1', alreadyMember: false);
  }

  @override
  Future<List<GroupModel>> getGroups() async => [];

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _guest = AuthSession.guest();
const _me = AuthSession(userId: 'u1', email: 'a@b.c', name: 'Ali');

const _notMember = InvitePreviewModel(
  groupName: 'Family Prayers',
  description: 'Daily',
  memberCount: 5,
  isMember: false,
  groupId: null,
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  required _Remote remote,
  required AuthSession session,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/invite/TOK',
    routes: [
      GoRoute(
        path: '/invite/:token',
        builder: (_, s) => JoinGroupScreen(token: s.pathParameters['token']!),
      ),
      GoRoute(
        path: '/groups',
        builder: (_, _) => const Scaffold(body: Text('GROUPS TAB')),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (_, s) =>
            Scaffold(body: Text('GROUP ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, s) => Scaffold(body: Text('LOGIN ${s.uri}')),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, s) => Scaffold(body: Text('SIGNUP ${s.uri}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(() => _Session(session)),
        groupsRemoteDataSourceProvider.overrideWithValue(remote),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return router;
}

void main() {
  testWidgets('guest sees the group and is sent to log in WITH a way back', (
    tester,
  ) async {
    final remote = _Remote()..preview = _notMember;
    await _pump(tester, remote: remote, session: _guest);
    expect(find.text('Family Prayers'), findsOneWidget);
    expect(find.text('5 members'), findsOneWidget);
    expect(find.text('Join group'), findsNothing);
    await tester.tap(find.text('Log in to join'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      find.textContaining('LOGIN /login?redirect=%2Finvite%2FTOK'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guest can also create an account and return to the invite', (
    tester,
  ) async {
    final remote = _Remote()..preview = _notMember;
    await _pump(tester, remote: remote, session: _guest);
    await tester.tap(find.text('Create an account'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      find.textContaining('SIGNUP /signup?redirect=%2Finvite%2FTOK'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signed-in non-member joins and lands in the group', (
    tester,
  ) async {
    final remote = _Remote()..preview = _notMember;
    await _pump(tester, remote: remote, session: _me);
    await tester.tap(find.text('Join group'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(remote.joins, ['TOK']);
    expect(find.text('GROUP gid-1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('join failure stays on the screen with the server message', (
    tester,
  ) async {
    final remote = _Remote()
      ..preview = _notMember
      ..joinError = const ServerException('Something went wrong joining');
    await _pump(tester, remote: remote, session: _me);
    await tester.tap(find.text('Join group'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Something went wrong joining'), findsOneWidget);
    expect(find.text('Join group'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('existing member gets Open group, not Join', (tester) async {
    final remote = _Remote()
      ..preview = const InvitePreviewModel(
        groupName: 'Family Prayers',
        description: null,
        memberCount: 5,
        isMember: true,
        groupId: 'gid-9',
      );
    await _pump(tester, remote: remote, session: _me);
    expect(find.text('Join group'), findsNothing);
    await tester.tap(find.text('Open group'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('GROUP gid-9'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('invalid or reset link shows the server message', (tester) async {
    final remote = _Remote()
      ..previewError = const ServerException(
        'This invite link is invalid or has been reset',
      );
    await _pump(tester, remote: remote, session: _me);
    expect(
      find.text('This invite link is invalid or has been reset'),
      findsOneWidget,
    );
    expect(find.text('Join group'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
