import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_reason.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_target.dart';
import 'package:deen_companion/features/moderation/presentation/moderation_flows.dart';
import 'package:deen_companion/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '_moderation_support.dart';

const _person = SafetyUser(
  id: 'u1',
  name: 'Sara Ahmed',
  avatarUrl: 'https://x.test/a.png',
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeModeration repo,
  Future<void> Function(BuildContext, WidgetRef) launch,
) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // The screens that start these flows already watch this, which
                // is what loads the list.
                ref.watch(blockedUserIdsProvider);
                return Center(
                  child: TextButton(
                    onPressed: () => launch(context, ref),
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('open'));
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('the safety menu for a person', () {
    testWidgets('Block: asks, blocks, and says how to undo it', (tester) async {
      final repo = FakeModeration();
      final c = await _pump(
        tester,
        repo,
        (ctx, ref) => showUserSafetyActions(ctx, ref, user: _person),
      );
      await tester.tap(find.text('Block Sara Ahmed'));
      await _settle(tester);
      expect(find.text('Block Sara Ahmed?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await _settle(tester);

      expect(repo.list.single.userId, 'u1');
      expect(repo.list.single.avatarUrl, 'https://x.test/a.png');
      expect(c.read(blockedUserIdsProvider), {'u1'});
      expect(
        find.text('Sara Ahmed is blocked. You can unblock them in Settings.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Block, then changing your mind, blocks no one and says nothing',
      (tester) async {
        final repo = FakeModeration();
        await _pump(
          tester,
          repo,
          (ctx, ref) => showUserSafetyActions(ctx, ref, user: _person),
        );
        await tester.tap(find.text('Block Sara Ahmed'));
        await _settle(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
        await _settle(tester);

        expect(repo.blockCalls, 0);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('Report: choose a reason and send', (tester) async {
      final repo = FakeModeration();
      await _pump(
        tester,
        repo,
        (ctx, ref) => showUserSafetyActions(ctx, ref, user: _person),
      );
      await tester.tap(find.text('Report Sara Ahmed'));
      await _settle(tester);
      await tester.tap(find.text('Harassment or bullying'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await _settle(tester);

      expect(repo.reports.single.target, isA<ReportUserTarget>());
      expect(repo.reports.single.target.userId, 'u1');
      expect(repo.reports.single.reason, ReportReason.harassment);
      expect(repo.blockCalls, 0, reason: 'reporting does not block by itself');
    });

    testWidgets('Report, then "Block": both happen, one after the other', (
      tester,
    ) async {
      final repo = FakeModeration();
      await _pump(
        tester,
        repo,
        (ctx, ref) => showUserSafetyActions(ctx, ref, user: _person),
      );
      await tester.tap(find.text('Report Sara Ahmed'));
      await _settle(tester);
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
      await _settle(tester);
      await tester.tap(find.text('Block Sara Ahmed'));
      await _settle(tester);

      expect(find.text('Block Sara Ahmed?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await _settle(tester);

      expect(repo.reports, hasLength(1));
      expect(repo.list.single.userId, 'u1');
      expect(find.textContaining('is blocked'), findsOneWidget);
    });

    testWidgets('someone already blocked is offered Unblock, and it works', (
      tester,
    ) async {
      final repo = FakeModeration([blocked('u1', name: 'Sara Ahmed')]);
      final c = await _pump(
        tester,
        repo,
        (ctx, ref) => showUserSafetyActions(ctx, ref, user: _person),
      );
      expect(find.text('Unblock Sara Ahmed'), findsOneWidget);

      await tester.tap(find.text('Unblock Sara Ahmed'));
      await _settle(tester);

      expect(repo.list, isEmpty);
      expect(c.read(blockedUserIdsProvider), isEmpty);
      expect(find.text('Sara Ahmed is unblocked.'), findsOneWidget);
    });

    testWidgets('a failed unblock says so', (tester) async {
      final repo = FakeModeration([blocked('u1', name: 'Sara Ahmed')]);
      await _pump(
        tester,
        repo,
        (ctx, ref) => showUserSafetyActions(ctx, ref, user: _person),
      );
      repo.failure = const CacheFailure(
        'Couldn’t unblock this person. Try again.',
      );
      await tester.tap(find.text('Unblock Sara Ahmed'));
      await _settle(tester);
      expect(
        find.text('Couldn’t unblock this person. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('closing the menu does nothing', (tester) async {
      final repo = FakeModeration();
      await _pump(
        tester,
        repo,
        (ctx, ref) => showUserSafetyActions(ctx, ref, user: _person),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await _settle(tester);
      expect(repo.blockCalls + repo.reports.length, 0);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('starting a report on a snap', () {
    const snap = ReportSnapTarget(
      snapId: 's9',
      userId: 'u1',
      userName: 'Sara Ahmed',
    );

    testWidgets('sends the snap, and its sender', (tester) async {
      final repo = FakeModeration();
      await _pump(tester, repo, (ctx, ref) => startReport(ctx, ref, snap));
      await tester.tap(find.text('Inappropriate content'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await _settle(tester);

      final t = repo.reports.single.target as ReportSnapTarget;
      expect(t.snapId, 's9');
      expect(t.userId, 'u1');
    });

    testWidgets('does not offer to block someone who is already blocked', (
      tester,
    ) async {
      final repo = FakeModeration([blocked('u1', name: 'Sara Ahmed')]);
      await _pump(tester, repo, (ctx, ref) => startReport(ctx, ref, snap));
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
      await _settle(tester);
      expect(find.textContaining('Block Sara'), findsNothing);
    });
  });

  group('SafetyUser', () {
    test('becomes a blocked record stamped with now', () {
      final before = DateTime.now();
      final b = _person.toBlocked();
      expect(b.userId, 'u1');
      expect(b.name, 'Sara Ahmed');
      expect(b.avatarUrl, 'https://x.test/a.png');
      expect(b.blockedAt.isBefore(before), isFalse);
    });
  });
}
