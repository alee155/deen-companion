import '../../domain/entities/qibla_info.dart';

class QiblaInfoModel {
  final double qiblaDirection;
  final String compassBearing;
  final double distanceKm;
  final double distanceMiles;
  final String note;

  // Not present in the remote API's response — attached by the repository
  // right after fetching (see withCoordinates), then round-tripped through
  // the cache via toJson/fromJson so a cached read carries them too.
  final double latitude;
  final double longitude;

  const QiblaInfoModel({
    required this.qiblaDirection,
    required this.compassBearing,
    required this.distanceKm,
    required this.distanceMiles,
    required this.note,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory QiblaInfoModel.fromJson(Map<String, dynamic> json) {
    return QiblaInfoModel(
      qiblaDirection: (json['qibla_direction'] as num).toDouble(),
      compassBearing: json['compass_bearing'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      distanceMiles: (json['distance_miles'] as num).toDouble(),
      note: json['note'] as String,
      // Defaults to 0.0 for two legitimate reasons: the remote API's JSON
      // never has these keys at all (they're attached after the fact — see
      // withCoordinates), and a cache entry saved before this field existed
      // won't have them either. Either way this degrades to an uncorrected
      // heading for one cache cycle, never a crash.
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'qibla_direction': qiblaDirection,
    'compass_bearing': compassBearing,
    'distance_km': distanceKm,
    'distance_miles': distanceMiles,
    'note': note,
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Attaches the coordinates this result was actually calculated for.
  /// Called once, right after a fresh fetch, before the result is cached.
  QiblaInfoModel withCoordinates(double latitude, double longitude) {
    return QiblaInfoModel(
      qiblaDirection: qiblaDirection,
      compassBearing: compassBearing,
      distanceKm: distanceKm,
      distanceMiles: distanceMiles,
      note: note,
      latitude: latitude,
      longitude: longitude,
    );
  }

  QiblaInfo toEntity() => QiblaInfo(
    qiblaDirection: qiblaDirection,
    compassBearing: compassBearing,
    distanceKm: distanceKm,
    distanceMiles: distanceMiles,
    note: note,
    latitude: latitude,
    longitude: longitude,
  );
}
