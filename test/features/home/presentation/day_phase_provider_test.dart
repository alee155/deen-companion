import 'dart:ui' show AppLifecycleState;

import 'package:deen_companion/features/home/presentation/providers/day_phase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayPhaseAt', () {
    DayPhase at(int h, [int m = 0]) => dayPhaseAt(DateTime(2026, 1, 1, h, m));

    test('maps hours to phases at the boundaries', () {
      expect(at(0), DayPhase.night);
      expect(at(4, 59), DayPhase.night);
      expect(at(5), DayPhase.morning);
      expect(at(15, 59), DayPhase.morning);
      expect(at(16), DayPhase.evening);
      expect(at(19, 59), DayPhase.evening);
      expect(at(20), DayPhase.night);
      expect(at(23, 59), DayPhase.night);
    });
  });

  group('nextDayPhaseChange', () {
    test('returns the next boundary today or tomorrow morning', () {
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 10)),
        DateTime(2026, 1, 1, 16),
      );
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 16)),
        DateTime(2026, 1, 1, 20),
      );
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 22)),
        DateTime(2026, 1, 2, 5),
      );
      expect(
        nextDayPhaseChange(DateTime(2026, 1, 1, 2)),
        DateTime(2026, 1, 1, 5),
      );
    });
  });

  testWidgets('provider moves to the next phase when the boundary passes', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1, 15, 59, 30);
    final container = ProviderContainer(
      overrides: [dayPhaseClockProvider.overrideWithValue(() => now)],
    );

    final seen = <DayPhase>[];
    container.listen(dayPhaseProvider, (_, next) => seen.add(next));
    expect(container.read(dayPhaseProvider), DayPhase.morning);

    now = DateTime(2026, 1, 1, 16, 0, 1);
    await tester.pump(const Duration(seconds: 31));

    expect(container.read(dayPhaseProvider), DayPhase.evening);
    expect(seen, [DayPhase.evening]);
    container.dispose();
  });

  testWidgets('provider re-syncs on app resume', (tester) async {
    var now = DateTime(2026, 1, 1, 10);
    final container = ProviderContainer(
      overrides: [dayPhaseClockProvider.overrideWithValue(() => now)],
    );
    container.listen(dayPhaseProvider, (_, _) {});
    expect(container.read(dayPhaseProvider), DayPhase.morning);

    now = DateTime(2026, 1, 1, 21);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(container.read(dayPhaseProvider), DayPhase.night);
    container.dispose();
  });
}
