import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/widgets/prayer_dots_row.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '_prayer_log_test_support.dart';

PrayerLog _log(PrayerName p, {String? url}) => PrayerLog(
  id: p.name,
  prayer: p,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: null,
  hasSnap: url != null,
  windowStartsAt: DateTime.now().subtract(const Duration(hours: 1)),
  windowEndsAt: DateTime.now().add(const Duration(hours: 1)),
  loggedAt: DateTime(2026, 10, 13, 5),
);

final _member = GroupMemberPrayers(
  userId: 'u',
  name: 'Sara Ahmed',
  role: GroupRole.member,
  logs: [
    _log(PrayerName.fajr, url: 'https://img.test/fajr.jpg'),
    _log(PrayerName.asr),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerLogsRepositoryProvider.overrideWithValue(
          ScriptedLogsRepo()
            ..viewResult = const Success(OpenedSnap(url: 'https://img.test/a')),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _labelled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

void main() {
  testWidgets('five circles, filled for the prayers logged', (tester) async {
    await _pump(tester, PrayerDotsRow(member: _member));
    expect(_labelled('Fajr logged'), findsOneWidget);
    expect(_labelled('Asr logged'), findsOneWidget);
    expect(_labelled('Dhuhr not logged'), findsOneWidget);
    expect(_labelled('Maghrib not logged'), findsOneWidget);
    expect(_labelled('Isha not logged'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('compact by default: no prayer names', (tester) async {
    await _pump(tester, PrayerDotsRow(member: _member));
    expect(find.text('Fajr'), findsNothing);
  });

  testWidgets('showLabels names every circle', (tester) async {
    await _pump(tester, PrayerDotsRow(member: _member, showLabels: true));
    for (final n in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
  });

  testWidgets('showLabels spreads the circles across the width', (
    tester,
  ) async {
    await _pump(tester, PrayerDotsRow(member: _member, showLabels: true));
    final first = tester.getTopLeft(find.text('Fajr')).dx;
    final last = tester.getTopRight(find.text('Isha')).dx;
    expect(last - first, greaterThan(250));
  });

  testWidgets('a logged prayer with a photo opens it when viewable', (
    tester,
  ) async {
    await _pump(tester, PrayerDotsRow(member: _member));
    await tester.tap(_labelled('Fajr logged'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('Sara Ahmed · Fajr'), findsOneWidget);
  });

  testWidgets('not viewable: tapping opens nothing', (tester) async {
    await _pump(tester, PrayerDotsRow(member: _member, viewable: false));
    await tester.tap(_labelled('Fajr logged'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('a logged prayer without a photo opens nothing', (tester) async {
    await _pump(tester, PrayerDotsRow(member: _member));
    await tester.tap(_labelled('Asr logged'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('the size parameter sets the circle diameter', (tester) async {
    await _pump(tester, PrayerDotsRow(member: _member, size: 40));
    final box = tester.getSize(_labelled('Fajr logged'));
    expect(box.width, closeTo(box.height, 0.01));
    expect(box.width, closeTo(40, 0.5));
  });
}
