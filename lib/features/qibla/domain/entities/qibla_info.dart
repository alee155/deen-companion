class QiblaInfo {
  final double qiblaDirection; // degrees from true north
  final String compassBearing; // e.g. "ENE"
  final double distanceKm;
  final double distanceMiles;
  final String note;

  const QiblaInfo({
    required this.qiblaDirection,
    required this.compassBearing,
    required this.distanceKm,
    required this.distanceMiles,
    required this.note,
  });
}
