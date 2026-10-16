import 'dart:async';

import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/groups/presentation/widgets/group_detail_skeleton.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

class _Session extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'admin1', email: 'a@b.c', name: 'Alee');
}

const _detail = GroupDetail(
  id: 'g1',
  name: 'Namaz Family Group',
  description: 'Daily recitation group',
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

void _phone(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpSkeleton(
  WidgetTester tester, {
  double width = 390,
  bool disableAnimations = false,
  int rows = 5,
}) async {
  _phone(tester, width: width);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          home: Scaffold(body: GroupDetailSkeleton(memberRows: rows)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// The group screen with a detail future the test controls.
Future<Completer<GroupDetail>> _pumpScreen(WidgetTester tester) async {
  _phone(tester);
  final completer = Completer<GroupDetail>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(_Session.new),
        groupDetailProvider('g1').overrideWith((ref) => completer.future),
        groupPrayersProvider.overrideWith((ref, key) async => const []),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) =>
            const MaterialApp(home: GroupDetailScreen(groupId: 'g1')),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return completer;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('the skeleton', () {
    testWidgets('draws the header and the member rows as shimmering shapes', (
      tester,
    ) async {
      await _pumpSkeleton(tester);
      // Header + members heading + members card: one shimmer each.
      expect(find.byType(Shimmer), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('draws as many member rows as asked', (tester) async {
      await _pumpSkeleton(tester, rows: 3);
      final three = tester.getSize(find.byType(GroupDetailSkeleton)).height;
      await tester.pumpWidget(const SizedBox());
      await _pumpSkeleton(tester, rows: 6);
      final six = tester.getSize(find.byType(GroupDetailSkeleton)).height;
      // Each extra row adds height (a row is ~66, plus a divider).
      expect(six - three, greaterThan(150));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the header is the dark gradient the real one uses', (
      tester,
    ) async {
      await _pumpSkeleton(tester);
      final hero = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(GroupDetailSkeleton),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = hero.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.borderRadius, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the members sit in a card like the real list', (tester) async {
      await _pumpSkeleton(tester);
      final cards = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.border != null &&
            d.borderRadius == BorderRadius.circular(24.r);
      });
      expect(cards, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('fits a ${width.toInt()}-wide phone without overflow', (
        tester,
      ) async {
        await _pumpSkeleton(tester, width: width);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('shimmers normally, and holds still with reduced motion', (
      tester,
    ) async {
      await _pumpSkeleton(tester);
      expect(
        tester
            .widgetList<Shimmer>(find.byType(Shimmer))
            .every((s) => s.enabled),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());

      await _pumpSkeleton(tester, disableAnimations: true);
      expect(
        tester.widgetList<Shimmer>(find.byType(Shimmer)).any((s) => s.enabled),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cannot be scrolled while it stands in for content', (
      tester,
    ) async {
      await _pumpSkeleton(tester);
      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(GroupDetailSkeleton),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scroll.physics, isA<NeverScrollableScrollPhysics>());
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('on the group screen', () {
    testWidgets('shows the skeleton while loading, not a spinner', (
      tester,
    ) async {
      final c = await _pumpScreen(tester);
      expect(find.byType(GroupDetailSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Namaz Family Group'), findsNothing);
      c.complete(_detail);
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the back button is there from the first frame', (
      tester,
    ) async {
      await _pumpScreen(tester);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      // No options button yet: there is no group to act on.
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no Send snap button until the group is known', (tester) async {
      final c = await _pumpScreen(tester);
      expect(find.byTooltip('Send snap'), findsNothing);
      c.complete(_detail);
      await _settle(tester);
      expect(find.byTooltip('Send snap'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('gives way to the real content when it arrives', (
      tester,
    ) async {
      final c = await _pumpScreen(tester);
      c.complete(_detail);
      await _settle(tester);

      expect(find.byType(GroupDetailSkeleton), findsNothing);
      expect(find.text('Namaz Family Group'), findsWidgets);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failure replaces the skeleton with the error', (
      tester,
    ) async {
      final c = await _pumpScreen(tester);
      c.completeError(Exception('offline'));
      await _settle(tester);

      expect(find.byType(GroupDetailSkeleton), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Try again shows the skeleton again while it reloads', (
      tester,
    ) async {
      var calls = 0;
      final first = Completer<GroupDetail>();
      final second = Completer<GroupDetail>();
      _phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(_Session.new),
            groupDetailProvider(
              'g1',
            ).overrideWith((ref) => (calls++ == 0 ? first : second).future),
            groupPrayersProvider.overrideWith((ref, key) async => const []),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) =>
                const MaterialApp(home: GroupDetailScreen(groupId: 'g1')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      first.completeError(Exception('offline'));
      await _settle(tester);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GroupDetailSkeleton), findsOneWidget);

      second.complete(_detail);
      await _settle(tester);
      expect(find.byType(GroupDetailSkeleton), findsNothing);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
