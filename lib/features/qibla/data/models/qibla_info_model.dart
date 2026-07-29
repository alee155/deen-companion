import '../../domain/entities/qibla_info.dart';

class QiblaInfoModel {
  final double qiblaDirection;
  final String compassBearing;
  final double distanceKm;
  final double distanceMiles;
  final String note;

  const QiblaInfoModel({
    required this.qiblaDirection,
    required this.compassBearing,
    required this.distanceKm,
    required this.distanceMiles,
    required this.note,
  });

  factory QiblaInfoModel.fromJson(Map<String, dynamic> json) {
    return QiblaInfoModel(
      qiblaDirection: (json['qibla_direction'] as num).toDouble(),
      compassBearing: json['compass_bearing'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      distanceMiles: (json['distance_miles'] as num).toDouble(),
      note: json['note'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'qibla_direction': qiblaDirection,
    'compass_bearing': compassBearing,
    'distance_km': distanceKm,
    'distance_miles': distanceMiles,
    'note': note,
  };

  QiblaInfo toEntity() => QiblaInfo(
    qiblaDirection: qiblaDirection,
    compassBearing: compassBearing,
    distanceKm: distanceKm,
    distanceMiles: distanceMiles,
    note: note,
  );
}
