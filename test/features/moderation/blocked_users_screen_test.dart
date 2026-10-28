import 'dart:async';

import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/moderation/domain/entities/blocked_user.dart';
import 'package:deen_companion/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:deen_companion/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:deen_companion/features/moderation/presentation/screens/blocked_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '_moderation_support.dart';

Future<void> _pump(WidgetTester tester, ModerationRepository repo) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const BlockedUsersScreen())],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('with nobody blocked: says so, and where to find the menu', (
    tester,
  ) async {
    await _pump(tester, FakeModeration());
    expect(find.text('Blocked users'), findsOneWidget);
    expect(find.text('No one is blocked'), findsOneWidget);
    expect(find.textContaining('report or block'), findsOneWidget);
    expect(find.text('Unblock'), findsNothing);
  });

  testWidgets('lists each blocked person with an Unblock button', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeModeration([
        blocked('a', name: 'Ali Khan'),
        blocked('b', name: 'Bilal Raza'),
      ]),
    );
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('Bilal Raza'), findsOneWidget);
    expect(find.text('Unblock'), findsNWidgets(2));
    expect(find.textContaining('aren’t told'), findsOneWidget);
  });

  testWidgets('a person saved without a name still has a row', (tester) async {
    await _pump(tester, FakeModeration([blocked('a', name: '')]));
    expect(find.text('Unknown user'), findsOneWidget);
  });

  testWidgets('Unblock removes the row at once and confirms', (tester) async {
    final repo = FakeModeration([
      blocked('a', name: 'Ali Khan'),
      blocked('b', name: 'Bilal Raza'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('Unblock').first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('Ali Khan'), findsNothing);
    expect(find.text('Bilal Raza'), findsOneWidget);
    expect(repo.list.map((b) => b.userId), ['b']);
    expect(find.text('Ali Khan is unblocked.'), findsOneWidget);
  });

  testWidgets('unblocking the last person shows the empty state', (
    tester,
  ) async {
    await _pump(tester, FakeModeration([blocked('a', name: 'Ali Khan')]));
    await tester.tap(find.text('Unblock'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('No one is blocked'), findsOneWidget);
  });

  testWidgets('a failed unblock keeps the person and says why', (tester) async {
    final repo = FakeModeration([blocked('a', name: 'Ali Khan')]);
    await _pump(tester, repo);
    repo.failure = const CacheFailure(
      'Couldn’t unblock this person. Try again.',
    );
    await tester.tap(find.text('Unblock'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(
      find.text('Couldn’t unblock this person. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('while loading it shows placeholders, not the empty state', (
    tester,
  ) async {
    final repo = _Slow();
    await _pump(tester, repo);
    expect(find.text('No one is blocked'), findsNothing);
    expect(find.text('Unblock'), findsNothing);
    repo.release();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('No one is blocked'), findsOneWidget);
  });

  testWidgets('a list that will not load offers to try again', (tester) async {
    final repo = FakeModeration()
      ..failure = const CacheFailure('Couldn’t load your blocked users.');
    await _pump(tester, repo);
    expect(find.text('Couldn’t load your blocked users.'), findsOneWidget);

    repo.failure = null;
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('No one is blocked'), findsOneWidget);
  });
}

/// A repository whose list arrives when the test says so.
class _Slow extends FakeModeration {
  final _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<Result<List<BlockedUser>>> getBlockedUsers() async {
    await _gate.future;
    return super.getBlockedUsers();
  }
}
