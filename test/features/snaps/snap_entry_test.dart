import 'package:deen_companion/features/snaps/domain/snap_availability.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:deen_companion/features/snaps/presentation/snap_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A page with one button that runs [openSnapFlow], over a stand-in flow that
/// closes with [result].
Future<List<String>> _pump(
  WidgetTester tester, {
  SnapAvailability availability = const SnapAvailability.available(),
  SnapAvailability? override,
  String? groupId,
  Object? result = 1,
}) async {
  final visited = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => openSnapFlow(
                context,
                ref,
                groupId: groupId,
                availability: override,
              ),
              child: const Text('camera'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/snap',
        builder: (context, _) {
          visited.add('/snap');
          return Scaffold(
            body: TextButton(
              onPressed: () => context.pop(result),
              child: const Text('finish'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/groups/:id/snap',
        builder: (context, s) {
          visited.add('/groups/${s.pathParameters['id']}/snap');
          return Scaffold(
            body: TextButton(
              onPressed: () => context.pop(result),
              child: const Text('finish'),
            ),
          );
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [snapAvailabilityProvider.overrideWithValue(availability)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  return visited;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('available: opens the flow and lets the user pick groups', (
    tester,
  ) async {
    final visited = await _pump(tester);
    await tester.tap(find.text('camera'));
    await _settle(tester);
    expect(visited, ['/snap']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('from a group: that group is passed to the flow', (tester) async {
    final visited = await _pump(tester, groupId: 'g7');
    await tester.tap(find.text('camera'));
    await _settle(tester);
    expect(visited, ['/groups/g7/snap']);
  });

  testWidgets('unavailable: a toast with the reason, and no flow', (
    tester,
  ) async {
    final visited = await _pump(
      tester,
      availability: const SnapAvailability.noGroups(),
    );
    await tester.tap(find.text('camera'));
    await _settle(tester);
    expect(visited, isEmpty);
    expect(
      find.text('Join or create a group to start sending snaps.'),
      findsOneWidget,
    );
  });

  testWidgets('an override from the screen wins over the prayer answer', (
    tester,
  ) async {
    final visited = await _pump(
      tester,
      availability: const SnapAvailability.available(),
      override: const SnapAvailability.noGroups(),
    );
    await tester.tap(find.text('camera'));
    await _settle(tester);
    expect(visited, isEmpty);
    expect(find.textContaining('Join or create a group'), findsOneWidget);
  });

  testWidgets('one group: "Snap sent"', (tester) async {
    await _pump(tester, result: 1);
    await tester.tap(find.text('camera'));
    await _settle(tester);
    await tester.tap(find.text('finish'));
    await _settle(tester);
    expect(find.text('Snap sent'), findsOneWidget);
  });

  testWidgets('several groups: says how many', (tester) async {
    await _pump(tester, result: 3);
    await tester.tap(find.text('camera'));
    await _settle(tester);
    await tester.tap(find.text('finish'));
    await _settle(tester);
    expect(find.text('Snap sent to 3 groups'), findsOneWidget);
  });

  testWidgets('leaving the flow without sending says nothing', (tester) async {
    await _pump(tester, result: null);
    await tester.tap(find.text('camera'));
    await _settle(tester);
    await tester.tap(find.text('finish'));
    await _settle(tester);
    expect(find.byType(SnackBar), findsNothing);
  });
}
