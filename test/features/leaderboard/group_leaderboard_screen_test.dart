import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/group_live/presentation/providers/group_live_store.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:deen_companion/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:deen_companion/features/leaderboard/presentation/providers/leaderboard_providers.dart';
import 'package:deen_companion/features/leaderboard/presentation/screens/group_leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../group_live/_live_support.dart';

class _Session extends AuthSessionNotifier {
  _Session(this.id);
  final String id;
  @override
  AuthSession build() => AuthSession(userId: id, email: '$id@b.c', name: id);
}

class _Repo implements LeaderboardRepository {
  _Repo(this.answers);

  /// One answer per call; the last one repeats.
  final List<Result<List<LeaderboardEntry>>> answers;
  int calls = 0;

  @override
  Future<Result<List<LeaderboardEntry>>> leaderboard(String groupId) async {
    final i = calls < answers.length ? calls : answers.length - 1;
    calls++;
    return answers[i];
  }
}

LeaderboardEntry _e(
  int rank,
  String id,
  String name, {
  int points = 10,
  GroupRole role = GroupRole.member,
}) => LeaderboardEntry(
  rank: rank,
  userId: id,
  name: name,
  role: role,
  points: points,
  prayersLogged: 7,
  currentStreak: 3,
);

final _four = [
  _e(1, 'u1', 'Alee Khan', points: 90, role: GroupRole.admin),
  _e(2, 'u2', 'Sara Ahmed', points: 70),
  _e(3, 'u3', 'Bilal Noor', points: 50),
  _e(4, 'u4', 'Hira Shah', points: 20),
];

const _detail = GroupDetail(
  id: 'g1',
  name: 'Family',
  members: [
    GroupMember(
      userId: 'u1',
      name: 'Alee Khan',
      email: 'a@b.c',
      role: GroupRole.admin,
    ),
  ],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pump(WidgetTester tester, _Repo repo, {String me = 'u4'}) async {
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
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
        leaderboardRepositoryProvider.overrideWithValue(repo),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) =>
            const MaterialApp(home: GroupLeaderboardScreen(groupId: 'g1')),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  testWidgets('shows the hero with the group name and where you stand', (
    tester,
  ) async {
    await _pump(tester, _Repo([Success(_four)]));
    expect(find.text('Leaderboard'), findsWidgets);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('You’re #4 of 4'), findsOneWidget);
    expect(find.text('20 pts'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the top three are on the podium, the rest in the list', (
    tester,
  ) async {
    await _pump(tester, _Repo([Success(_four)]));
    // Podium: name over "N pts".
    expect(find.text('Alee Khan'), findsOneWidget);
    expect(find.text('90 pts'), findsOneWidget);
    expect(find.text('Sara Ahmed'), findsOneWidget);
    expect(find.text('Bilal Noor'), findsOneWidget);
    // List: only rank 4, with prayers and streak.
    expect(find.text('Hira Shah (you)'), findsOneWidget);
    expect(find.text('7 prayers'), findsOneWidget);
    expect(find.text('3d'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with fewer than three members everyone is in the list', (
    tester,
  ) async {
    await _pump(
      tester,
      _Repo([
        Success([
          _e(1, 'u1', 'Alee Khan', points: 40, role: GroupRole.admin),
          _e(2, 'u4', 'Hira Shah', points: 10),
        ]),
      ]),
    );
    expect(find.text('Alee Khan'), findsOneWidget);
    expect(find.text('Hira Shah (you)'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('You’re #2 of 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ten members: podium of three, seven rows, long names fit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ten = [
      for (var i = 1; i <= 10; i++)
        _e(
          i,
          'u$i',
          'Muhammad Abdurrahman Ibn Khalid Number $i',
          points: 100 - i * 5,
          role: i == 1 ? GroupRole.admin : GroupRole.member,
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupSummaryRemoteDataSourceProvider.overrideWithValue(
            FakeSummaryRemote(),
          ),
          authSessionProvider.overrideWith(() => _Session('u7')),
          groupDetailProvider('g1').overrideWith((ref) async => _detail),
          leaderboardRepositoryProvider.overrideWithValue(
            _Repo([Success(ten)]),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              const MaterialApp(home: GroupLeaderboardScreen(groupId: 'g1')),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('You’re #7 of 10'), findsOneWidget);
    // Scroll to the last row: ranks 4..10 are rows, 1..3 the podium.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await _settle(tester);
    expect(find.textContaining('Number 10'), findsOneWidget);
    expect(find.textContaining('Number 7 (you)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failure shows a retry that loads the board', (tester) async {
    final repo = _Repo([const Error(NetworkFailure()), Success(_four)]);
    await _pump(tester, repo);
    expect(find.text('Alee Khan'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await _settle(tester);
    expect(repo.calls, 2);
    expect(find.text('Alee Khan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pull to refresh asks the server again', (tester) async {
    final repo = _Repo([Success(_four)]);
    await _pump(tester, repo);
    expect(repo.calls, 1);
    // The indicator fires after a quarter of the viewport has been pulled.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await _settle(tester);
    expect(repo.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
