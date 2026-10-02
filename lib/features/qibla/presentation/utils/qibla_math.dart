// Pure helpers for the Qibla finder screen, kept free of Flutter so they
// can be unit tested.

/// Signed shortest rotation (degrees, -180..180] needed to go from [current]
/// to [target]. Positive means "turn clockwise / to the right".
double shortestAngleDiff(double target, double current) {
  var diff = (target - current) % 360;
  if (diff > 180) diff -= 360;
  if (diff <= -180) diff += 360;
  return diff;
}

/// Normalises any angle into 0..<360.
double normalizeDegrees(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}

/// 16-point compass label (N, NNE, NE …) for a bearing in degrees.
String compassLabel(double degrees) {
  const labels = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];
  return labels[(normalizeDegrees(degrees) / 22.5).round() % 16];
}

/// Sensor accuracy is in degrees (lower is better). Some platforms signal
/// "unreliable" with a negative value, so both are treated as needing
/// calibration. Null (nothing reported) is "unknown", not "bad".
bool isLowCompassAccuracy(double? accuracy) {
  if (accuracy == null) return false;
  return accuracy < 0 || accuracy > 25;
}

/// How far (degrees) the heading may be from the Qibla to count as aligned.
const double qiblaMatchToleranceDegrees = 6;
