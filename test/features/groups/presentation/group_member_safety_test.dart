import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/group_live/presentation/providers/group_live_store.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/groups/presentation/widgets/snap_widgets.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_target.dart';
import 'package:deen_companion/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../group_live/_live_support.dart';
import '../../moderation/_moderation_support.dart';
import '../../streaks/_streaks_support.dart';

class _Session extends AuthSessionNotifier {
  final String id;
  _Session(this.id);
  @override
  AuthSession build() => AuthSession(userId: id, email: '$id@b.c', name: id);
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

final _noon = DateTime(2026, 10, 13, 12);

PrayerLog _log(PrayerName p, String id, String url) => PrayerLog(
  id: id,
  prayer: p,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: url,
  windowStartsAt: _noon.subtract(const Duration(hours: 1)),
  windowEndsAt: _noon.add(const Duration(hours: 1)),
  loggedAt: _noon,
);

final _feed = [
  GroupMemberPrayers(
    userId: 'admin1',
    name: 'Alee Khan',
    role: GroupRole.admin,
    logs: [_log(PrayerName.fajr, 'a1', 'https://img.test/a.jpg')],
  ),
  GroupMemberPrayers(
    userId: 'member1',
    name: 'Sara Ahmed',
    role: GroupRole.member,
    logs: [_log(PrayerName.asr, 's1', 'https://img.test/s.jpg')],
  ),
];

Future<FakeModeration> _pump(
  WidgetTester tester, {
  required String me,
  FakeModeration? moderation,
}) async {
  final repo = moderation ?? FakeModeration();
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
        groupPrayersProvider.overrideWith((ref, key) async => _feed),
        streaksRepositoryProvider.overrideWithValue(FakeStreaksRepo()),
        moderationRepositoryProvider.overrideWithValue(repo),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) =>
            const MaterialApp(home: GroupDetailScreen(groupId: 'g1')),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  return repo;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder get _more => find.byIcon(Icons.more_vert_rounded);
Finder get _blockedTag => find.text('BLOCKED');

/// A widget test with semantics on: several checks read the tree (for example,
/// whether a snap can be opened), and the handle must be released inside the
/// test.
void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });
}

/// Whether Sara's snap can be opened (her row's photo button).
bool _canOpenSnap(WidgetTester tester) => find
    .byWidgetPredicate((w) => w is SnapBox && w.hasPhoto && w.onTap != null)
    .evaluate()
    .isNotEmpty;

void main() {
  group('who gets the ⋯ menu', () {
    _test('on everyone else, not on yourself (as an admin)', (tester) async {
      await _pump(tester, me: 'admin1');
      expect(_more, findsOneWidget);
      expect(find.byTooltip('More about Sara Ahmed'), findsOneWidget);
      expect(find.byTooltip('More about Alee Khan'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    _test('a regular member has it too, whatever their role', (tester) async {
      await _pump(tester, me: 'member1');
      expect(_more, findsOneWidget);
      expect(find.byTooltip('More about Alee Khan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  _test('the menu offers to report and to block that person', (tester) async {
    await _pump(tester, me: 'admin1');
    await tester.tap(_more);
    await _settle(tester);
    expect(find.text('Report Sara Ahmed'), findsOneWidget);
    expect(find.text('Block Sara Ahmed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  group('blocking from a member row', () {
    _test('marks them Blocked and hides their snap', (tester) async {
      final repo = await _pump(tester, me: 'admin1');
      expect(_blockedTag, findsNothing);
      expect(_canOpenSnap(tester), isTrue);

      await tester.tap(_more);
      await _settle(tester);
      await tester.tap(find.text('Block Sara Ahmed'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await _settle(tester);

      expect(repo.list.single.userId, 'member1');
      expect(_blockedTag, findsOneWidget);
      expect(_canOpenSnap(tester), isFalse);
      expect(find.textContaining('is blocked'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    _test('someone blocked earlier is marked from the start', (tester) async {
      await _pump(
        tester,
        me: 'admin1',
        moderation: FakeModeration([blocked('member1', name: 'Sara Ahmed')]),
      );
      expect(_blockedTag, findsOneWidget);
      expect(_canOpenSnap(tester), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    _test('their menu offers Unblock, and it brings the snap back', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        me: 'admin1',
        moderation: FakeModeration([blocked('member1', name: 'Sara Ahmed')]),
      );
      await tester.tap(_more);
      await _settle(tester);
      expect(find.text('Unblock Sara Ahmed'), findsOneWidget);
      expect(find.text('Block Sara Ahmed'), findsNothing);

      await tester.tap(find.text('Unblock Sara Ahmed'));
      await _settle(tester);

      expect(repo.list, isEmpty);
      expect(_blockedTag, findsNothing);
      expect(_canOpenSnap(tester), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    _test('blocking one person does not affect the others', (tester) async {
      await _pump(
        tester,
        me: 'member1',
        moderation: FakeModeration([blocked('someone-else')]),
      );
      expect(_blockedTag, findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reporting from a member row', () {
    _test('reports the person, then offers to block', (tester) async {
      final repo = await _pump(tester, me: 'admin1');
      await tester.tap(_more);
      await _settle(tester);
      await tester.tap(find.text('Report Sara Ahmed'));
      await _settle(tester);
      await tester.tap(find.text('Spam or a scam'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
      await _settle(tester);

      expect(repo.reports.single.target, isA<ReportUserTarget>());
      expect(repo.reports.single.target.userId, 'member1');
      expect(find.text('Block Sara Ahmed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the photo viewer', () {
    Future<void> openSnap(WidgetTester tester) async {
      await tester.tap(
        find.byWidgetPredicate((w) => w is SnapBox && w.hasPhoto),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    _test("has a ⋯ menu on someone else's snap", (tester) async {
      await _pump(tester, me: 'admin1');
      await openSnap(tester);

      expect(find.byTooltip('More'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    _test('Report snap closes the viewer and reports that snap', (
      tester,
    ) async {
      final repo = await _pump(tester, me: 'admin1');
      await openSnap(tester);

      await tester.tap(find.byTooltip('More'));
      await _settle(tester);
      expect(find.text('Report snap'), findsOneWidget);
      expect(find.text('Block this person'), findsOneWidget);

      await tester.tap(find.text('Report snap'));
      await _settle(tester);
      // The viewer is gone and the report sheet is up, about this snap.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('A snap from Sara Ahmed'), findsOneWidget);

      await tester.tap(find.text('Inappropriate content'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
      await _settle(tester);

      final t = repo.reports.single.target as ReportSnapTarget;
      expect(t.snapId, 's1', reason: 'the prayer log the photo belongs to');
      expect(t.userId, 'member1');
      await tester.pumpWidget(const SizedBox());
    });

    _test('Block this person closes the viewer and asks to confirm', (
      tester,
    ) async {
      await _pump(tester, me: 'admin1');
      await openSnap(tester);

      await tester.tap(find.byTooltip('More'));
      await _settle(tester);
      await tester.tap(find.text('Block this person'));
      await _settle(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Block Sara Ahmed?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    _test('closing the menu keeps the snap open', (tester) async {
      await _pump(tester, me: 'admin1');
      await openSnap(tester);

      await tester.tap(find.byTooltip('More'));
      await _settle(tester);
      await tester.tapAt(const Offset(10, 600)); // outside the menu
      await _settle(tester);

      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason: 'still viewing',
      );
      await tester.pumpWidget(const SizedBox());
    });

    _test('while the menu is open the countdown does not close the snap', (
      tester,
    ) async {
      await _pump(tester, me: 'admin1');
      await openSnap(tester);

      await tester.tap(find.byTooltip('More'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 20)); // far longer than a snap
      expect(
        find.text('Report snap'),
        findsOneWidget,
        reason: 'menu still open',
      );
      expect(
        find.byTooltip('Close'),
        findsOneWidget,
        reason: 'snap still open',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
