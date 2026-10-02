import 'package:deen_companion/features/qibla/data/models/qibla_info_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json() => {
  'qibla_direction': 245.5,
  'compass_bearing': 'WSW',
  'distance_km': 3500,
  'distance_miles': 2174.8,
  'note': 'From true north',
};

void main() {
  group('QiblaInfoModel.fromJson', () {
    test(
      'parses API payload; ints coerce to double; coordinates default to 0',
      () {
        final m = QiblaInfoModel.fromJson(_json());
        expect(m.qiblaDirection, 245.5);
        expect(m.compassBearing, 'WSW');
        expect(m.distanceKm, 3500.0);
        expect(m.distanceKm, isA<double>());
        expect(m.latitude, 0.0);
        expect(m.longitude, 0.0);
      },
    );

    test('reads coordinates when present (cache entries)', () {
      final m = QiblaInfoModel.fromJson({
        ..._json(),
        'latitude': 51.5,
        'longitude': -0.12,
      });
      expect(m.latitude, 51.5);
      expect(m.longitude, -0.12);
    });

    test('integer coordinates are accepted', () {
      final m = QiblaInfoModel.fromJson({
        ..._json(),
        'latitude': 40,
        'longitude': -74,
      });
      expect(m.latitude, 40.0);
      expect(m.longitude, -74.0);
    });

    test('missing required field throws', () {
      for (final k in [
        'qibla_direction',
        'compass_bearing',
        'distance_km',
        'distance_miles',
        'note',
      ]) {
        final j = _json()..remove(k);
        expect(
          () => QiblaInfoModel.fromJson(j),
          throwsA(isA<TypeError>()),
          reason: k,
        );
      }
    });

    test('wrong-typed direction (string) throws', () {
      expect(
        () => QiblaInfoModel.fromJson({..._json(), 'qibla_direction': '245'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('serialisation and entity mapping', () {
    test('toJson/fromJson round-trips including coordinates', () {
      final m = QiblaInfoModel.fromJson(_json()).withCoordinates(24.7, 46.7);
      final back = QiblaInfoModel.fromJson(m.toJson());
      expect(back.toJson(), m.toJson());
      expect(back.latitude, 24.7);
    });

    test('withCoordinates keeps all other fields and does not mutate', () {
      final base = QiblaInfoModel.fromJson(_json());
      final located = base.withCoordinates(1.5, 2.5);
      expect(base.latitude, 0.0);
      expect(located.qiblaDirection, base.qiblaDirection);
      expect(located.note, base.note);
      expect(located.longitude, 2.5);
    });

    test('toEntity carries bearing and coordinates', () {
      final e = QiblaInfoModel.fromJson(
        _json(),
      ).withCoordinates(3, 4).toEntity();
      expect(e.qiblaDirection, 245.5);
      expect(e.latitude, 3);
      expect(e.longitude, 4);
      expect(e.compassBearing, 'WSW');
      expect(e.distanceMiles, 2174.8);
    });
  });
}
