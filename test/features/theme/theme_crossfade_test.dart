import 'package:deen_companion/core/motion/motion.dart';
import 'package:deen_companion/core/theme/app_colors.dart';
import 'package:deen_companion/features/theme/presentation/widgets/theme_crossfade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _inits = 0;

/// Reads AppColors in build() like most screens do, from a const subtree that
/// nothing else would rebuild.
class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _inits++;
  }

  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: const Key('probe'), color: AppColors.parchment);
}

Widget _app(ThemeVariant v) {
  AppColors.applyVariant(v); // what the root widget does before building
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: MotionScope(
        level: MotionLevel.standard,
        child: ThemeCrossfade(variant: v, child: const _Probe()),
      ),
    ),
  );
}

void main() {
  setUp(() => _inits = 0);
  tearDown(() => AppColors.applyVariant(ThemeVariant.light));

  testWidgets('a look change repaints const subtrees without remounting them', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ThemeVariant.light));
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('probe'))).color,
      AppColors.parchment,
    );
    final light = AppColors.parchment;

    await tester.pumpWidget(_app(ThemeVariant.isha));
    await tester.pump(const Duration(seconds: 1));
    final shown = tester
        .widget<ColoredBox>(find.byKey(const Key('probe')))
        .color;
    expect(shown, AppColors.parchment);
    expect(shown, isNot(light));
    expect(_inits, 1, reason: 'state must survive the switch');
  });

  testWidgets('an unchanged look does not rebuild the subtree', (tester) async {
    await tester.pumpWidget(_app(ThemeVariant.light));
    await tester.pumpWidget(_app(ThemeVariant.light));
    expect(_inits, 1);
  });

  testWidgets('reduced motion still switches, with no fade layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ThemeCrossfade(
            variant: ThemeVariant.light,
            child: const _Probe(),
          ),
        ),
      ),
    );
    AppColors.applyVariant(ThemeVariant.dark);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ThemeCrossfade(
            variant: ThemeVariant.dark,
            child: const _Probe(),
          ),
        ),
      ),
    );
    expect(find.byType(RawImage), findsNothing);
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('probe'))).color,
      AppColors.parchment,
    );
  });
}
