import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/manual_city_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:deen_companion/features/prayer_times/presentation/screens/city_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../_support/prayer_area_support.dart';

const _lahore = PrayerCity(
  name: 'Lahore',
  region: 'Punjab',
  country: 'Pakistan',
  countryCode: 'PK',
  latitude: 31.558,
  longitude: 74.3507,
  timezone: 'Asia/Karachi',
);

const _lahor = PrayerCity(
  name: 'Kili Lahor',
  region: 'Balochistan',
  country: 'Pakistan',
  countryCode: 'PK',
  latitude: 30.3956,
  longitude: 68.7627,
  timezone: 'Asia/Karachi',
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakePrayerRepo repo, {
  PrayerCity? alreadyChosen,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final storage = PaStorage();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      prayerTimesRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  if (alreadyChosen != null) {
    await container.read(manualCityProvider.notifier).select(alreadyChosen);
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
      ),
      GoRoute(
        path: '/prayer-times/city',
        builder: (_, _) => const CityPickerScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  router.push<bool>('/prayer-times/city');
  await tester.pumpAndSettle();
  return container;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  // Past the 400 ms debounce, then let the result render.
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(initFlavorForTests);

  testWidgets('starts with a hint and no results', (tester) async {
    await _pump(tester, FakePrayerRepo());
    expect(find.text('Choose a city'), findsOneWidget);
    expect(find.textContaining('Type at least 2 letters'), findsOneWidget);
  });

  testWidgets('shows results with region and country', (tester) async {
    final repo = FakePrayerRepo()
      ..citiesResult = const Success([_lahore, _lahor]);
    await _pump(tester, repo);
    await _type(tester, 'Lahore');
    expect(find.widgetWithText(ListTile, 'Lahore'), findsOneWidget);
    expect(find.text('Punjab, Pakistan'), findsOneWidget);
    expect(find.text('Kili Lahor'), findsOneWidget);
    expect(find.text('Balochistan, Pakistan'), findsOneWidget);
    expect(repo.calls, ['cities Lahore']);
  });

  testWidgets('picking a city saves it and closes the screen', (tester) async {
    final repo = FakePrayerRepo()..citiesResult = const Success([_lahore]);
    final c = await _pump(tester, repo);
    await _type(tester, 'Lahore');

    await tester.tap(find.widgetWithText(ListTile, 'Lahore'));
    await tester.pumpAndSettle();

    expect(c.read(manualCityProvider), _lahore);
    expect(find.text('SETTINGS'), findsOneWidget, reason: 'screen closed');
  });

  testWidgets('no match says so', (tester) async {
    final repo = FakePrayerRepo()..citiesResult = const Success([]);
    await _pump(tester, repo);
    await _type(tester, 'Zzzz');
    expect(find.textContaining('No city found for'), findsOneWidget);
  });

  testWidgets('an error offers to try again', (tester) async {
    final repo = FakePrayerRepo()..citiesResult = const Error(NetworkFailure());
    await _pump(tester, repo);
    await _type(tester, 'Lahore');
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsOneWidget);

    repo.citiesResult = const Success([_lahore]);
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.widgetWithText(ListTile, 'Lahore'), findsOneWidget);
  });

  testWidgets('with a city chosen, "use device location" clears it', (
    tester,
  ) async {
    final c = await _pump(tester, FakePrayerRepo(), alreadyChosen: _lahore);
    expect(
      find.textContaining('Use my device location instead (now: Lahore)'),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Use my device location'));
    await tester.pumpAndSettle();

    expect(c.read(manualCityProvider), isNull);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('without a chosen city there is no "device location" button', (
    tester,
  ) async {
    await _pump(tester, FakePrayerRepo());
    expect(find.textContaining('Use my device location'), findsNothing);
  });
}
