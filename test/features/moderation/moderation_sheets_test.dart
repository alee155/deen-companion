import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_reason.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_target.dart';
import 'package:deen_companion/features/moderation/presentation/moderation_flows.dart';
import 'package:deen_companion/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:deen_companion/features/moderation/presentation/widgets/block_sheet.dart';
import 'package:deen_companion/features/moderation/presentation/widgets/report_sheet.dart';
import 'package:deen_companion/features/moderation/presentation/widgets/user_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '_moderation_support.dart';

const _user = ReportUserTarget(userId: 'u1', userName: 'Sara Ahmed');
const _snap = ReportSnapTarget(
  snapId: 's1',
  userId: 'u1',
  userName: 'Sara Ahmed',
);
const _person = SafetyUser(id: 'u1', name: 'Sara Ahmed');

/// A page with a button that runs [launch] and records what it returns.
class _Rig {
  final FakeModeration repo;
  Object? result;
  _Rig(this.repo);
}

Future<_Rig> _pump(
  WidgetTester tester,
  Future<Object?> Function(BuildContext, WidgetRef) launch, {
  FakeModeration? repo,
  double height = 900,
}) async {
  tester.view.physicalSize = Size(390 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final rig = _Rig(repo ?? FakeModeration());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [moderationRepositoryProvider.overrideWithValue(rig.repo)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: TextButton(
                  onPressed: () async =>
                      rig.result = await launch(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return rig;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Finder _submit() => find.widgetWithText(FilledButton, 'Submit report');

void main() {
  group('report sheet', () {
    testWidgets('lists every reason', (tester) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));

      for (final text in [
        'Inappropriate content',
        'Harassment or bullying',
        'Spam or a scam',
        'Pretending to be someone else',
        'Something else',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets(
      'the chosen reason says what it covers; the others stay short',
      (tester) async {
        await _pump(tester, (c, _) => showReportSheet(c, target: _user));
        expect(
          find.text('Nudity, violence or anything unsuitable'),
          findsNothing,
        );

        await tester.tap(find.text('Inappropriate content'));
        await _settle(tester);
        expect(
          find.text('Nudity, violence or anything unsuitable'),
          findsOneWidget,
        );
        expect(
          find.text('Insults, threats or targeting someone'),
          findsNothing,
        );

        await tester.tap(find.text('Harassment or bullying'));
        await _settle(tester);
        expect(
          find.text('Nudity, violence or anything unsuitable'),
          findsNothing,
        );
        expect(
          find.text('Insults, threats or targeting someone'),
          findsOneWidget,
        );
      },
    );

    testWidgets('on a small phone the Submit button is on screen', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _user),
        height: 667,
      );
      await tester.tap(find.text('Something else'));
      await _settle(tester);
      final box = tester.getRect(_submit());
      expect(box.bottom, lessThanOrEqualTo(667));
      expect(box.top, greaterThan(0));
    });

    testWidgets('titles the sheet for a person, or for a snap', (tester) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));
      expect(find.text('Report Sara Ahmed'), findsOneWidget);
      expect(find.text('Tell us what’s wrong.'), findsOneWidget);
    });

    testWidgets('a snap report says it is about a snap, from whom', (
      tester,
    ) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _snap));
      expect(find.text('Report snap'), findsOneWidget);
      expect(find.text('A snap from Sara Ahmed'), findsOneWidget);
    });

    testWidgets('cannot be sent until a reason is chosen', (tester) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));
      expect(tester.widget<FilledButton>(_submit()).onPressed, isNull);

      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      expect(tester.widget<FilledButton>(_submit()).onPressed, isNotNull);
    });

    testWidgets('one reason at a time', (tester) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(find.text('Harassment or bullying'));
      await tester.pump();

      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(4),
      );
    });

    testWidgets('sends the reason, the note and the target', (tester) async {
      final repo = FakeModeration();
      await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _snap),
        repo: repo,
      );

      await tester.tap(find.text('Inappropriate content'));
      await tester.enterText(
        find.byType(TextField),
        '  not suitable for the group ',
      );
      await tester.pump();
      await tester.tap(_submit());
      await _settle(tester);

      expect(repo.reports, hasLength(1));
      expect(repo.reports.single.target, _snap);
      expect(repo.reports.single.reason, ReportReason.inappropriate);
      expect(repo.reports.single.details, 'not suitable for the group');
    });

    testWidgets('the note is limited to 300 characters', (tester) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));
      await tester.enterText(find.byType(TextField), 'x' * 400);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, ReportSheet.maxDetails);
      expect(field.controller!.text.length, ReportSheet.maxDetails);
    });

    testWidgets('says the person is not told, and that people review it', (
      tester,
    ) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));
      expect(
        find.textContaining('Sara Ahmed isn’t told who reported them'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Our team reviews every report'),
        findsOneWidget,
      );
    });

    testWidgets('shows sending, and the form cannot be changed meanwhile', (
      tester,
    ) async {
      final repo = FakeModeration()..hold = true;
      await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _user),
        repo: repo,
      );
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(_submit());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      final cancel = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      expect(cancel.onPressed, isNull);
      await _settle(tester);
    });

    testWidgets('a failure keeps the sheet open, with the reason and a retry', (
      tester,
    ) async {
      final repo = FakeModeration()
        ..failure = const ServerFailure('Server is busy.');
      await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _user),
        repo: repo,
      );
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(_submit());
      await _settle(tester);

      expect(find.text('Server is busy.'), findsOneWidget);
      expect(
        find.text('Spam or a scam'),
        findsOneWidget,
        reason: 'still the form',
      );

      repo.failure = null;
      await tester.tap(_submit());
      await _settle(tester);
      expect(find.text('Report sent'), findsOneWidget);
    });

    testWidgets('afterwards: thanks, and an offer to block them', (
      tester,
    ) async {
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(_submit());
      await _settle(tester);

      expect(find.text('Report sent'), findsOneWidget);
      expect(find.text('Thanks for letting us know.'), findsOneWidget);
      expect(find.text('Block Sara Ahmed'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    });

    testWidgets('"Done" closes as sent', (tester) async {
      final rig = await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _user),
      );
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(_submit());
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await _settle(tester);
      expect(rig.result, ReportOutcome.sent);
    });

    testWidgets('"Block" closes as sent-and-block', (tester) async {
      final rig = await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _user),
      );
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(_submit());
      await _settle(tester);
      await tester.tap(find.text('Block Sara Ahmed'));
      await _settle(tester);
      expect(rig.result, ReportOutcome.sentAndBlock);
    });

    testWidgets('someone already blocked is not offered again', (tester) async {
      await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _user, alreadyBlocked: true),
      );
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(_submit());
      await _settle(tester);
      expect(find.text('Report sent'), findsOneWidget);
      expect(find.textContaining('Block Sara'), findsNothing);
    });

    testWidgets('"Cancel" closes without sending', (tester) async {
      final repo = FakeModeration();
      final rig = await _pump(
        tester,
        (c, _) => showReportSheet(c, target: _user),
        repo: repo,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await _settle(tester);
      expect(rig.result, ReportOutcome.cancelled);
      expect(repo.reports, isEmpty);
    });

    testWidgets('screen readers hear each reason as one choice of several', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, (c, _) => showReportSheet(c, target: _user));
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();

      final picked = tester.getSemantics(
        find.bySemanticsLabel(
          'Spam or a scam. Unwanted promotion or misleading links',
        ),
      );
      expect(picked.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      handle.dispose();
    });
  });

  group('block sheet', () {
    testWidgets('says exactly what blocking does', (tester) async {
      await _pump(tester, (c, _) => showBlockSheet(c, user: _person));
      expect(find.text('Block Sara Ahmed?'), findsOneWidget);
      expect(find.text('Their snaps are hidden from you.'), findsOneWidget);
      expect(
        find.text('Sara Ahmed isn’t told that you blocked them.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('unblock them any time in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('Block blocks them and closes with true', (tester) async {
      final repo = FakeModeration();
      final rig = await _pump(
        tester,
        (c, _) => showBlockSheet(c, user: _person),
        repo: repo,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await _settle(tester);

      expect(rig.result, isTrue);
      expect(repo.list.single.userId, 'u1');
      expect(repo.list.single.name, 'Sara Ahmed');
    });

    testWidgets('Cancel blocks no one', (tester) async {
      final repo = FakeModeration();
      final rig = await _pump(
        tester,
        (c, _) => showBlockSheet(c, user: _person),
        repo: repo,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await _settle(tester);

      expect(rig.result, isFalse);
      expect(repo.blockCalls, 0);
    });

    testWidgets('a failure stays on the sheet with the message', (
      tester,
    ) async {
      final repo = FakeModeration()
        ..failure = const CacheFailure(
          'Couldn’t block this person. Try again.',
        );
      final rig = await _pump(
        tester,
        (c, _) => showBlockSheet(c, user: _person),
        repo: repo,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await _settle(tester);

      expect(
        find.text('Couldn’t block this person. Try again.'),
        findsOneWidget,
      );
      expect(rig.result, isNull, reason: 'the sheet is still open');

      repo.failure = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await _settle(tester);
      expect(rig.result, isTrue);
    });
  });

  group('actions sheet', () {
    testWidgets('offers Report and Block for someone not blocked', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, _) => showUserActionsSheet(c, user: _person, isBlocked: false),
      );
      expect(find.text('Report Sara Ahmed'), findsOneWidget);
      expect(find.text('Block Sara Ahmed'), findsOneWidget);
      expect(find.text('Unblock Sara Ahmed'), findsNothing);
    });

    testWidgets('offers Unblock, not Block, for someone blocked', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, _) => showUserActionsSheet(c, user: _person, isBlocked: true),
      );
      expect(find.text('Unblock Sara Ahmed'), findsOneWidget);
      expect(find.text('Block Sara Ahmed'), findsNothing);
      expect(find.text('Report Sara Ahmed'), findsOneWidget);
    });

    for (final (label, action) in [
      ('Report Sara Ahmed', UserAction.report),
      ('Block Sara Ahmed', UserAction.block),
    ]) {
      testWidgets('tapping "$label" picks ${action.name}', (tester) async {
        final rig = await _pump(
          tester,
          (c, _) => showUserActionsSheet(c, user: _person, isBlocked: false),
        );
        await tester.tap(find.text(label));
        await _settle(tester);
        expect(rig.result, action);
      });
    }

    testWidgets('Unblock picks unblock', (tester) async {
      final rig = await _pump(
        tester,
        (c, _) => showUserActionsSheet(c, user: _person, isBlocked: true),
      );
      await tester.tap(find.text('Unblock Sara Ahmed'));
      await _settle(tester);
      expect(rig.result, UserAction.unblock);
    });

    testWidgets('Cancel picks nothing', (tester) async {
      final rig = await _pump(
        tester,
        (c, _) => showUserActionsSheet(c, user: _person, isBlocked: false),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await _settle(tester);
      expect(rig.result, isNull);
    });
  });
}
