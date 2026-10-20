import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/points/presentation/providers/points_providers.dart';
import 'package:deen_companion/features/points/presentation/screens/points_rules_screen.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../streaks/_streaks_support.dart';
import '../_points_support.dart';

class _Session extends AuthSessionNotifier {
  _Session(this.id);
  final String id;
  @override
  AuthSession build() => AuthSession(userId: id, email: '$id@b.c', name: id);
}

const _detail = GroupDetail(
  id: 'g1',
  name: 'Family',
  members: [
    GroupMember(
      userId: 'admin1',
      name: 'Alee',
      email: 'a@b.c',
      role: GroupRole.admin,
    ),
    GroupMember(
      userId: 'member1',
      name: 'Sara',
      email: 's@b.c',
      role: GroupRole.member,
    ),
  ],
);

Future<FakeStreaksRepo> pump(
  WidgetTester tester, {
  String? groupId,
  String me = 'admin1',
  FakeStreaksRepo? streaks,
}) async {
  final repo = streaks ?? FakeStreaksRepo();
  tester.view.physicalSize = const Size(390 * 3, 2200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(() => _Session(me)),
        groupDetailProvider('g1').overrideWith((ref) async => _detail),
        pointsRepositoryProvider.overrideWithValue(
          FakePointsRepo()..result = Success(sampleRules()),
        ),
        streaksRepositoryProvider.overrideWithValue(repo),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) =>
            MaterialApp(home: PointsRulesScreen(groupId: groupId)),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return repo;
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  testWidgets('without a group there is no daily goal', (tester) async {
    await pump(tester);
    expect(find.text('Points per prayer'), findsOneWidget);
    expect(find.text('Daily goal'), findsNothing);
  });

  testWidgets('for a group, the goal sits between the chart and How it works', (
    tester,
  ) async {
    await pump(tester, groupId: 'g1');
    final chart = tester.getTopLeft(find.text('Points per prayer')).dy;
    final goal = tester.getTopLeft(find.text('Daily goal').first).dy;
    final how = tester.getTopLeft(find.text('How it works')).dy;
    expect(chart, lessThan(goal));
    expect(goal, lessThan(how));
    expect(find.text('Log at least 1 prayer a day'), findsOneWidget);
  });

  testWidgets('the admin can change the goal right here', (tester) async {
    final repo = await pump(tester, groupId: 'g1', me: 'admin1');
    expect(find.text('Save goal'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('5 prayers a day'));
    await tester.pump();
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(repo.setRuleCalls, [5]);
    expect(find.text('Log all 5 prayers every day'), findsOneWidget);
  });

  testWidgets('a member sees the goal but has no controls', (tester) async {
    await pump(tester, groupId: 'g1', me: 'member1');
    expect(find.text('Log at least 1 prayer a day'), findsOneWidget);
    expect(find.text('Save goal'), findsNothing);
    expect(find.bySemanticsLabel('3 prayers a day'), findsNothing);
  });

  testWidgets('a goal that fails to load does not break the rules', (
    tester,
  ) async {
    final repo = FakeStreaksRepo()..rule = offline;
    await pump(tester, groupId: 'g1', streaks: repo);
    expect(find.text('Couldn’t load this group’s daily goal.'), findsOneWidget);
    expect(find.text('Points per prayer'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
  });
}
