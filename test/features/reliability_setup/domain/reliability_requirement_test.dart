import 'package:deen_companion/features/reliability_setup/domain/reliability_requirement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReliabilityRequirement', () {
    test('declared in the order they are asked for', () {
      expect(ReliabilityRequirement.values, [
        ReliabilityRequirement.location,
        ReliabilityRequirement.notifications,
        ReliabilityRequirement.exactAlarms,
        ReliabilityRequirement.fullScreenAlerts,
        ReliabilityRequirement.batteryOptimization,
      ]);
    });

    test('every requirement has user-facing copy', () {
      for (final r in ReliabilityRequirement.values) {
        expect(r.title.trim(), isNotEmpty, reason: r.name);
        expect(r.why.trim(), isNotEmpty, reason: r.name);
      }
    });
  });

  group('ReliabilityStatusX', () {
    ReliabilityStatus status(Map<ReliabilityRequirement, bool> m) => m;

    test('all granted -> nothing missing', () {
      final s = status({for (final r in ReliabilityRequirement.values) r: true});
      expect(s.missing, isEmpty);
      expect(s.allGranted, isTrue);
    });

    test('missing lists only the denied ones, in map order', () {
      final s = status({
        ReliabilityRequirement.location: true,
        ReliabilityRequirement.notifications: false,
        ReliabilityRequirement.exactAlarms: true,
        ReliabilityRequirement.batteryOptimization: false,
      });
      expect(s.missing, [
        ReliabilityRequirement.notifications,
        ReliabilityRequirement.batteryOptimization,
      ]);
      expect(s.allGranted, isFalse);
    });

    test('an empty status counts as all granted', () {
      expect(status({}).allGranted, isTrue);
    });
  });
}
