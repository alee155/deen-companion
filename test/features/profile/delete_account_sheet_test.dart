import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/features/auth/presentation/providers/delete_account_controller.dart';
import 'package:deen_companion/features/profile/presentation/widgets/delete_account_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDelete extends DeleteAccountController {
  final bool succeeds;
  int calls = 0;
  _FakeDelete({required this.succeeds});

  @override
  Future<bool> delete() async {
    calls++;
    state = succeeds
        ? const DeleteAccountState()
        : const DeleteAccountState(errorMessage: 'Server said no');
    return succeeds;
  }
}

Future<bool?> _open(
  WidgetTester tester,
  _FakeDelete fake, {
  List<String>? links,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  bool? result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [deleteAccountControllerProvider.overrideWith(() => fake)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    DeleteAccountSheet(onOpenLink: (u) async => links?.add(u)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows the warning and what is kept', (tester) async {
    await _open(tester, _FakeDelete(succeeds: true));
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
    expect(find.textContaining('kept'), findsWidgets);
  });

  testWidgets('Cancel closes without deleting', (tester) async {
    final fake = _FakeDelete(succeeds: true);
    await _open(tester, fake);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsNothing);
    expect(fake.calls, 0);
  });

  testWidgets('a failed delete stays open and says why', (tester) async {
    final fake = _FakeDelete(succeeds: false);
    await _open(tester, fake);
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(fake.calls, 1);
    expect(find.text('Server said no'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
  });

  testWidgets('a successful delete closes the sheet', (tester) async {
    final fake = _FakeDelete(succeeds: true);
    await _open(tester, fake);
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(fake.calls, 1);
    expect(find.text('Delete account?'), findsNothing);
  });

  testWidgets('the link opens the delete-account page', (tester) async {
    final links = <String>[];
    await _open(tester, _FakeDelete(succeeds: true), links: links);
    await tester.tap(find.text('See what is deleted and what is kept'));
    expect(links, [AppConstants.deleteAccountUrl]);
  });
}
