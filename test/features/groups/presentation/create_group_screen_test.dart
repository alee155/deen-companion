import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/create_group_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../snaps/snap_fakes.dart';

void main() {
  testWidgets('the form asks only for what is sent, with no privacy options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myGroupsProvider.overrideWith(() => FakeMyGroups(const [])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => const MaterialApp(home: CreateGroupScreen()),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // The name and the description, the fields that reach the server.
    expect(find.byType(TextFormField), findsNWidgets(2));

    // The options that did nothing are gone.
    expect(find.text('Public group'), findsNothing);
    expect(find.text('Private group'), findsNothing);
    expect(find.text('Admin approval'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    // What is true is said instead.
    expect(find.textContaining('invite link'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
