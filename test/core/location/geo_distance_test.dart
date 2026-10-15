import 'package:deen_companion/core/location/geo_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the same point is zero kilometres away', () {
    expect(distanceKm(31.5204, 74.3587, 31.5204, 74.3587), 0);
  });

  test('Lahore to Karachi is about 1,030 km', () {
    final d = distanceKm(31.5204, 74.3587, 24.8607, 67.0011);
    expect(d, inInclusiveRange(1000, 1060));
  });

  test('a short hop across Lahore is under 10 km', () {
    expect(distanceKm(31.5204, 74.3587, 31.45, 74.30), lessThan(10));
  });

  test('is symmetric', () {
    final a = distanceKm(31.5, 74.3, 24.8, 67.0);
    final b = distanceKm(24.8, 67.0, 31.5, 74.3);
    expect(a, closeTo(b, 1e-9));
  });

  test('handles the antimeridian and the poles without NaN', () {
    expect(distanceKm(0, 179.9, 0, -179.9).isFinite, isTrue);
    expect(distanceKm(90, 0, -90, 0), closeTo(20015, 20));
  });
}
