import 'package:deen_companion/features/group_live/presentation/providers/group_live_store.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:deen_companion/features/groups/data/models/group_model.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../streaks/_streaks_support.dart';
import '../../group_live/_live_support.dart';

class _Session extends AuthSessionNotifier {
  final String id;
  _Session(this.id);
  @override
  AuthSession build() => AuthSession(userId: id, email: '$id@b.c', name: id);
}

class _InviteRemote implements GroupsRemoteDataSource {
  int version = 0;
  GroupInviteModel _i(String id) {
    final t = 'tok-$id-$version';
    return GroupInviteModel(token: t, url: 'https://x.test/invite/$t');
  }

  final removed = <String>[];
  final left = <String>[];

  @override
  Future<void> removeMember(String groupId, String userId) async =>
      removed.add(userId);
  @override
  Future<void> leaveGroup(String groupId) async => left.add(groupId);

  @override
  Future<GroupInviteModel> getInvite(String groupId) async => _i(groupId);
  @override
  Future<GroupInviteModel> resetInvite(String groupId) async {
    version++;
    return _i(groupId);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _detail = GroupDetail(
  id: 'g1',
  name: 'Namaz Family Group',
  description: 'Daily recitation group',
  inviteCode: 'JbwjmgCS',
  members: [
    GroupMember(
      userId: 'admin1',
      name: 'Alee Khan',
      email: 'alee@b.c',
      role: GroupRole.admin,
    ),
    GroupMember(
      userId: 'member1',
      name: 'Sara Ahmed',
      email: 's@b.c',
      role: GroupRole.member,
    ),
  ],
);

Future<_InviteRemote> _pump(WidgetTester tester, {required String me}) async {
  final remote = _InviteRemote();
  tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupSummaryRemoteDataSourceProvider.overrideWithValue(
          FakeSummaryRemote(),
        ),
        authSessionProvider.overrideWith(() => _Session(me)),
        groupDetailProvider('g1').overrideWith((ref) async => _detail),
        groupsRemoteDataSourceProvider.overrideWithValue(remote),
        streaksRepositoryProvider.overrideWithValue(FakeStreaksRepo()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) =>
            const MaterialApp(home: GroupDetailScreen(groupId: 'g1')),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  return remote;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('shows real group info and every member', (tester) async {
    await _pump(tester, me: 'admin1');
    expect(find.text('Namaz Family Group'), findsWidgets);
    expect(find.text('Daily recitation group'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(find.textContaining('Alee Khan'), findsOneWidget);
    expect(find.text('Sara Ahmed'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    // Each member card shows their real streak, from the board.
    expect(find.text('4d'), findsOneWidget);
    expect(find.text('2d'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manage sheet lists edit, invite and delete', (tester) async {
    await _pump(tester, me: 'admin1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await _settle(tester);
    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Invite link'), findsOneWidget);
    expect(find.text('Delete group'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('delete is locked until the group name is typed', (tester) async {
    await _pump(tester, me: 'admin1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await _settle(tester);
    await tester.tap(find.text('Delete group'));
    await _settle(tester);
    // Destructive confirmation state is showing, button disabled.
    expect(find.textContaining('can’t be undone'), findsOneWidget);
    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete group'),
    );
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'wrong name');
    await tester.pump();
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Namaz Family Group');
    await tester.pump(const Duration(milliseconds: 300));
    expect(button().onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'hero Invite chip opens the link for THIS group; admin can reset',
    (tester) async {
      await _pump(tester, me: 'admin1');
      await tester.tap(find.text('Invite'));
      await _settle(tester);
      expect(
        find.textContaining('https://x.test/invite/tok-g1-0'),
        findsOneWidget,
      );
      expect(find.text('Reset invite link'), findsOneWidget);
      await tester.tap(find.text('Reset invite link'));
      await _settle(tester);
      expect(find.textContaining('stops working right away'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Reset link'));
      await tester.pump(const Duration(milliseconds: 100));
      await _settle(tester);
      expect(find.textContaining('tok-g1-1'), findsWidgets);
      expect(find.textContaining('New link created'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('regular members can see/copy the link but not reset it', (
    tester,
  ) async {
    await _pump(tester, me: 'member1');
    await tester.tap(find.text('Invite'));
    await _settle(tester);
    expect(find.textContaining('tok-g1-0'), findsWidgets);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Reset invite link'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('edit sheet: save locked until something changes', (
    tester,
  ) async {
    await _pump(tester, me: 'admin1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await _settle(tester);
    await tester.tap(find.text('Edit details'));
    await _settle(tester);
    FilledButton save() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save().onPressed, isNull);
    expect(find.text('No changes yet'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Office Namaz Group',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(save().onPressed, isNotNull);
    expect(find.text('Save changes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('regular members get options but no edit/delete', (tester) async {
    await _pump(tester, me: 'member1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await _settle(tester);
    expect(find.text('Group options'), findsOneWidget);
    expect(find.text('Invite link'), findsOneWidget);
    expect(find.text('Leave group'), findsOneWidget);
    expect(find.text('Edit details'), findsNothing);
    expect(find.text('Delete group'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin menu also offers leave', (tester) async {
    await _pump(tester, me: 'admin1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await _settle(tester);
    expect(find.text('Leave group'), findsOneWidget);
    expect(find.text('Delete group'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('member leaving: confirmation, then API call and exit', (
    tester,
  ) async {
    final remote = await _pump(tester, me: 'member1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await _settle(tester);
    await tester.tap(find.text('Leave group'));
    await _settle(tester);
    expect(find.textContaining('rejoin later'), findsOneWidget);
    expect(remote.left, isEmpty); // nothing happens before confirming
    await tester.tap(find.widgetWithText(FilledButton, 'Leave group'));
    await _settle(tester);
    expect(remote.left, ['g1']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin leaving is told the next member becomes admin', (
    tester,
  ) async {
    await _pump(tester, me: 'admin1');
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await _settle(tester);
    await tester.tap(find.text('Leave group'));
    await _settle(tester);
    expect(
      find.textContaining('next member becomes the admin'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin removes a member only after confirming', (tester) async {
    final remote = await _pump(tester, me: 'admin1');
    await tester.tap(find.text('Sara Ahmed'));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.text('Remove from group'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Remove from group'));
    await _settle(tester);
    expect(find.text('Remove member'), findsOneWidget);
    expect(remote.removed, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await _settle(tester);
    expect(remote.removed, ['member1']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin has no remove button on their own detail sheet', (
    tester,
  ) async {
    await _pump(tester, me: 'admin1');
    await tester.tap(find.textContaining('Alee Khan'));
    await _settle(tester);
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.text('Remove from group'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'admin can open a member\'s details naming whose activity it is',
    (tester) async {
      await _pump(tester, me: 'admin1');
      await tester.tap(find.text('Sara Ahmed'));
      await _settle(tester);
      await _settle(tester);
      expect(find.textContaining('Admin view'), findsOneWidget);
      expect(find.textContaining('Sara Ahmed’s activity'), findsOneWidget);
      expect(find.text('Day streak'), findsOneWidget);
      expect(find.text('Best streak'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a regular member cannot open another member\'s details', (
    tester,
  ) async {
    await _pump(tester, me: 'member1');
    await tester.tap(find.text('Alee Khan'));
    await _settle(tester);
    expect(find.text('Best streak'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
