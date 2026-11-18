import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/widgets/calculation_settings_sheets.dart';
import 'package:deen_companion/shared/widgets/islamic_ornaments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettings extends PrayerCalculationSettingsNotifier {
  AsrSchool? picked;
  PrayerCalculationMethod? pickedMethod;

  @override
  PrayerCalculationSettings build() => PrayerCalculationSettings.pakistan;

  @override
  Future<void> setSchool(AsrSchool school) async => picked = school;

  @override
  Future<void> setMethod(PrayerCalculationMethod method) async =>
      pickedMethod = method;
}

void main() {
  late _FakeSettings fake;

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef) show,
  ) async {
    fake = _FakeSettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prayerCalculationSettingsProvider.overrideWith(() => fake)],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => show(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Asr school sheet has the textured header and both schools', (
    tester,
  ) async {
    await open(tester, showAsrSchoolPicker);
    expect(find.text('Asr juristic school'), findsOneWidget);
    expect(find.byType(GeometricPattern), findsOneWidget);
    for (final school in AsrSchool.values) {
      expect(find.text(school.label), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('picking a school saves it and closes the sheet', (tester) async {
    await open(tester, showAsrSchoolPicker);
    final other = AsrSchool.values.firstWhere(
      (s) => s != PrayerCalculationSettings.pakistan.school,
    );
    await tester.tap(find.text(other.label));
    await tester.pumpAndSettle();
    expect(fake.picked, other);
    expect(find.text('Asr juristic school'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('calculation method sheet has the textured header and a list', (
    tester,
  ) async {
    await open(tester, showCalculationMethodPicker);
    expect(find.text('Calculation method'), findsOneWidget);
    expect(find.byType(GeometricPattern), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
