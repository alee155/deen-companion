class QiblaInfo {
  final double qiblaDirection; // degrees from true north
  final String compassBearing; // e.g. "ENE"
  final double distanceKm;
  final double distanceMiles;
  final String note;

  // The coordinates this was calculated for — carried alongside the result
  // (rather than re-fetched separately) so the magnetic declination
  // correction is guaranteed to match the exact location the Qibla bearing
  // itself was computed for, not a possibly-slightly-different fresh fix.
  final double latitude;
  final double longitude;

  const QiblaInfo({
    required this.qiblaDirection,
    required this.compassBearing,
    required this.distanceKm,
    required this.distanceMiles,
    required this.note,
    required this.latitude,
    required this.longitude,
  });
}
