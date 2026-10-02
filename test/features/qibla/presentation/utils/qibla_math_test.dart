import 'package:flutter_test/flutter_test.dart';

import 'package:deen_companion/features/qibla/presentation/utils/qibla_math.dart';

void main() {
  group('shortestAngleDiff', () {
    test('turns the short way across north', () {
      expect(shortestAngleDiff(10, 350), closeTo(20, 1e-9));
      expect(shortestAngleDiff(350, 10), closeTo(-20, 1e-9));
    });

    test('is zero when aligned and ±180 at the opposite bearing', () {
      expect(shortestAngleDiff(90, 90), 0);
      expect(shortestAngleDiff(180, 0).abs(), closeTo(180, 1e-9));
    });

    test('handles inputs outside 0..360', () {
      expect(shortestAngleDiff(370, 0), closeTo(10, 1e-9));
      expect(shortestAngleDiff(-10, 0), closeTo(-10, 1e-9));
    });
  });

  test('normalizeDegrees wraps into 0..<360', () {
    expect(normalizeDegrees(-30), 330);
    expect(normalizeDegrees(360), 0);
    expect(normalizeDegrees(725), 5);
  });

  group('compassLabel', () {
    test('maps cardinal and intercardinal bearings', () {
      expect(compassLabel(0), 'N');
      expect(compassLabel(90), 'E');
      expect(compassLabel(225), 'SW');
      expect(compassLabel(258), 'WSW');
    });

    test('wraps just below 360 back to N', () {
      expect(compassLabel(359), 'N');
      expect(compassLabel(-10), 'N');
    });
  });

  group('isLowCompassAccuracy', () {
    test('flags negative (unreliable) and poor readings', () {
      expect(isLowCompassAccuracy(-1), isTrue);
      expect(isLowCompassAccuracy(30), isTrue);
    });

    test('accepts good readings and treats null as unknown', () {
      expect(isLowCompassAccuracy(10), isFalse);
      expect(isLowCompassAccuracy(25), isFalse);
      expect(isLowCompassAccuracy(null), isFalse);
    });
  });
}
