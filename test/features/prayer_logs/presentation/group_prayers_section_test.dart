import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_logs/presentation/widgets/group_prayers_section.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '_prayer_log_test_support.dart';

Future<void> _pump(WidgetTester tester, ScriptedLogsRepo repo) async {
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(SignedIn.new),
        prayerLogsRepositoryProvider.overrideWithValue(repo),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GroupPrayersSection(groupId: 'g1'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  testWidgets('lists members, most prayers first, with you marked', (
    tester,
  ) async {
    final repo = ScriptedLogsRepo()
      ..feedResult = Success([
        const GroupMemberPrayers(
          userId: 'u2',
          name: 'Hamza',
          role: GroupRole.member,
          logs: [],
        ),
        GroupMemberPrayers(
          userId: 'me',
          name: 'Ali',
          role: GroupRole.admin,
          logs: [
            logOf(PrayerName.fajr, points: 10),
            logOf(PrayerName.dhuhr, id: 'l2'),
          ],
        ),
      ]);
    await _pump(tester, repo);

    expect(find.text('Today’s prayers'), findsOneWidget);
    expect(find.text('Ali (you)'), findsOneWidget);
    expect(find.text('2 of 5 · 15 pts'), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
    final ali = tester.getTopLeft(find.text('Ali (you)')).dy;
    final hamza = tester.getTopLeft(find.text('Hamza')).dy;
    expect(ali, lessThan(hamza));
  });

  testWidgets('a non-member sees the server message with Retry', (
    tester,
  ) async {
    final repo = ScriptedLogsRepo()
      ..feedResult = const Error(
        PrayerLogFailure(
          'Not a member',
          code: PrayerLogErrorCode.notGroupMember,
          statusCode: 403,
        ),
      );
    await _pump(tester, repo);
    expect(find.textContaining('Only members of this group'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
