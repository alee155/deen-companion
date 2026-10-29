import 'package:deen_companion/core/app_info/app_info_service.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/profile/domain/entities/user_profile.dart';
import 'package:deen_companion/features/profile/presentation/providers/profile_providers.dart';
import 'package:deen_companion/features/profile/presentation/screens/profile_screen.dart';
import 'package:deen_companion/features/special_days/domain/special_days.dart';
import 'package:deen_companion/features/special_days/presentation/providers/special_days_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../prayer_logs/presentation/_prayer_log_test_support.dart';
import '../snaps/snap_fakes.dart';

class _Eligible extends SpecialDaysNotifier {
  @override
  Future<SpecialDays> build() async => const SpecialDays(eligible: true);
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(SignedIn.new),
        profileProvider.overrideWith(
          (ref) async =>
              const UserProfile(id: 'me', name: 'Me', email: 'm@b.c'),
        ),
        myPointsProvider.overrideWith((ref) async => UserPoints.empty),
        myGroupsProvider.overrideWith(() => FakeMyGroups(sampleGroups)),
        appVersionNameProvider.overrideWith((ref) async => '1.0.0'),
        specialDaysProvider.overrideWith(_Eligible.new),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
            ],
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Whether anything between [finder] and the screen paints it at zero opacity.
bool _hidden(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .any((o) => o.opacity == 0);

void main() {
  testWidgets('everything down to the footer shows, even below the fold', (
    tester,
  ) async {
    await _pump(tester);
    for (final label in [
      'Settings',
      'Special days',
      'Reset password',
      'Log out',
      'Delete account',
    ]) {
      final f = find.text(label);
      expect(f, findsOneWidget, reason: label);
      expect(_hidden(tester, f), isFalse, reason: '$label is invisible');
    }
    expect(find.textContaining('v1.0.0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('and the list scrolls to the last row', (tester) async {
    await _pump(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pump(const Duration(milliseconds: 600));
    final delete = find.text('Delete account');
    // Within the screen, above the bottom tab bar's room.
    expect(tester.getTopLeft(delete).dy, lessThan(844 - 100));
    expect(find.textContaining('v1.0.0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
