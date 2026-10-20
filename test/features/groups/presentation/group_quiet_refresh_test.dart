import 'dart:async';

import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/domain/repositories/groups_repository.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/groups/presentation/widgets/group_detail_skeleton.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../prayer_logs/presentation/_prayer_log_test_support.dart';
import '../../streaks/_streaks_support.dart';

/// A session whose user a test can switch.
class _Session extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'admin1', email: 'a@b.c', name: 'Alee');

  void switchTo(String id) =>
      state = AuthSession(userId: id, email: '$id@b.c', name: id);
}

const _detail = GroupDetail(
  id: 'g1',
  name: 'Namaz Family Group',
  members: [
    GroupMember(
      userId: 'admin1',
      name: 'Alee Khan',
      email: 'a@b.c',
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

/// Only the group call is real; anything else would throw, so a test cannot
/// quietly depend on something it did not set up.
class _GroupsRepo extends Fake implements GroupsRepository {
  int detailCalls = 0;
  Future<Result<GroupDetail>> Function(int call)? behavior;

  @override
  Future<Result<GroupDetail>> getGroupDetail(String groupId) {
    detailCalls++;
    return behavior?.call(detailCalls) ?? Future.value(const Success(_detail));
  }
}

class _FeedRepo extends ScriptedLogsRepo {
  int feedCalls = 0;
  Future<Result<List<GroupMemberPrayers>>> Function(int call)? behavior;

  @override
  Future<Result<List<GroupMemberPrayers>>> getGroupPrayers(
    String groupId, {
    String? date,
  }) {
    feedCalls++;
    return behavior?.call(feedCalls) ?? Future.value(const Success([]));
  }
}

class _Harness {
  final ProviderContainer container;
  final _GroupsRepo groups;
  final _FeedRepo feed;

  /// Whether the group screen is currently on screen. The provider scope
  /// stays mounted either way, as it does for the life of the real app.
  final visible = ValueNotifier<bool>(false);
  bool _mounted = false;

  _Harness(this.container, this.groups, this.feed);
}

_Harness _harness() {
  final groups = _GroupsRepo();
  final feed = _FeedRepo();
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(_Session.new),
      groupsRepositoryProvider.overrideWithValue(groups),
      prayerLogsRepositoryProvider.overrideWithValue(feed),
      streaksRepositoryProvider.overrideWithValue(FakeStreaksRepo()),
      currentPrayerProvider.overrideWith(() => FixedCurrent(openState())),
    ],
  );
  return _Harness(container, groups, feed);
}

/// Shows the group screen (mounting the app root the first time).
Future<void> _open(WidgetTester tester, _Harness h) async {
  h.visible.value = true;
  if (h._mounted) {
    await tester.pump();
    return;
  }
  h._mounted = true;
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => ValueListenableBuilder<bool>(
          valueListenable: h.visible,
          builder: (_, visible, _) => visible
              ? const MaterialApp(home: GroupDetailScreen(groupId: 'g1'))
              : const SizedBox(),
        ),
      ),
    ),
  );
}

/// Leaves the screen; the container (and what it kept) stays.
Future<void> _leave(WidgetTester tester, _Harness h) async {
  h.visible.value = false;
  await tester.pump();
  // Riverpod notices the last listener has gone a frame later, and only then
  // starts the keep-alive clock.
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _finish(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(const SizedBox());
  h.container.dispose();
}

bool _skeleton() => find.byType(GroupDetailSkeleton).evaluate().isNotEmpty;

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('coming back to a group', () {
    testWidgets('the first visit loads behind a skeleton', (tester) async {
      final h = _harness();
      final gate = Completer<Result<GroupDetail>>();
      h.groups.behavior = (_) => gate.future;
      await _open(tester, h);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_skeleton(), isTrue);

      gate.complete(const Success(_detail));
      await _settle(tester);
      expect(_skeleton(), isFalse);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      await _finish(tester, h);
    });

    testWidgets('the second visit shows the group on the first frame', (
      tester,
    ) async {
      final h = _harness();
      await _open(tester, h);
      await _settle(tester);
      await _leave(tester, h);
      await tester.pump(const Duration(minutes: 2));

      await _open(tester, h);
      await tester.pump(); // one frame, no waiting
      expect(_skeleton(), isFalse, reason: 'no skeleton for data we hold');
      expect(find.text('Sara Ahmed'), findsOneWidget);
      await _finish(tester, h);
    });

    testWidgets('and brings it up to date behind the scenes', (tester) async {
      final h = _harness();
      await _open(tester, h);
      await _settle(tester);
      expect(h.groups.detailCalls, 1);
      expect(h.feed.feedCalls, 1);
      await _leave(tester, h);

      await _open(tester, h);
      await _settle(tester);
      expect(h.groups.detailCalls, 2, reason: 'refreshed on reopen');
      expect(h.feed.feedCalls, 2);
      await _finish(tester, h);
    });

    testWidgets('nothing flashes while that refresh is under way', (
      tester,
    ) async {
      final h = _harness();
      await _open(tester, h);
      await _settle(tester);
      await _leave(tester, h);

      final gate = Completer<Result<GroupDetail>>();
      h.groups.behavior = (_) => gate.future;
      await _open(tester, h);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        expect(_skeleton(), isFalse, reason: 'frame $i');
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Sara Ahmed'), findsOneWidget);
      }
      gate.complete(const Success(_detail));
      await _settle(tester);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      await _finish(tester, h);
    });

    testWidgets('a failed refresh leaves what was on screen alone', (
      tester,
    ) async {
      final h = _harness();
      await _open(tester, h);
      await _settle(tester);
      await _leave(tester, h);

      h.groups.behavior = (_) async => const Error(NetworkFailure());
      await _open(tester, h);
      await _settle(tester);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(_skeleton(), isFalse);
      await _finish(tester, h);
    });

    testWidgets('after the keep-alive time it loads from scratch again', (
      tester,
    ) async {
      final h = _harness();
      await _open(tester, h);
      await _settle(tester);
      await _leave(tester, h);
      await tester.pump(groupDataKeepAlive + const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 100)); // disposal frame

      final gate = Completer<Result<GroupDetail>>();
      h.groups.behavior = (_) => gate.future;
      await _open(tester, h);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_skeleton(), isTrue, reason: 'the held data had expired');
      gate.complete(const Success(_detail));
      await _settle(tester);
      await _finish(tester, h);
    });

    testWidgets('another account never sees the previous one\'s group', (
      tester,
    ) async {
      final h = _harness();
      await _open(tester, h);
      await _settle(tester);
      await _leave(tester, h);

      (h.container.read(authSessionProvider.notifier) as _Session).switchTo(
        'someone-else',
      );
      await tester.pump();

      final gate = Completer<Result<GroupDetail>>();
      h.groups.behavior = (_) => gate.future;
      await _open(tester, h);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_skeleton(), isTrue);
      expect(find.text('Sara Ahmed'), findsNothing);
      gate.complete(const Success(_detail));
      await _settle(tester);
      await _finish(tester, h);
    });
  });

  group('while the group is open', () {
    Future<_Harness> opened(WidgetTester tester) async {
      final h = _harness();
      await _open(tester, h);
      await _settle(tester);
      return h;
    }

    testWidgets('it never calls the server on its own while open', (
      tester,
    ) async {
      final h = await opened(tester);
      final feed = h.feed.feedCalls;
      final detail = h.groups.detailCalls;
      await tester.pump(const Duration(minutes: 10));
      expect(h.feed.feedCalls, feed);
      expect(h.groups.detailCalls, detail);
      await _finish(tester, h);
    });

    testWidgets('nothing happens in the background either', (tester) async {
      final h = await opened(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final before = h.feed.feedCalls;
      await tester.pump(const Duration(minutes: 5));
      expect(h.feed.feedCalls, before);
      await _finish(tester, h);
    });

    testWidgets('coming back refreshes the group and the feed at once', (
      tester,
    ) async {
      final h = await opened(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 5));
      final detail = h.groups.detailCalls;
      final feed = h.feed.feedCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.groups.detailCalls, detail + 1);
      expect(h.feed.feedCalls, feed + 1);
      expect(_skeleton(), isFalse);
      await _finish(tester, h);
    });

    testWidgets('quickly returning twice refreshes only once', (tester) async {
      final h = await opened(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 5));
      final detail = h.groups.detailCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(h.groups.detailCalls, detail + 1, reason: 'throttled');
      await _finish(tester, h);
    });

    testWidgets('leaving the screen stops all of it', (tester) async {
      final h = await opened(tester);
      await _leave(tester, h);
      final detail = h.groups.detailCalls;
      final feed = h.feed.feedCalls;
      await tester.pump(const Duration(minutes: 5));
      expect(h.groups.detailCalls, detail);
      expect(h.feed.feedCalls, feed);
      h.container.dispose();
    });

    testWidgets('pull-to-refresh still works', (tester) async {
      final h = await opened(tester);
      final before = h.groups.detailCalls;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
      await tester.pump(const Duration(milliseconds: 100));
      await _settle(tester);
      expect(h.groups.detailCalls, greaterThan(before));
      await _finish(tester, h);
    });
  });
}
