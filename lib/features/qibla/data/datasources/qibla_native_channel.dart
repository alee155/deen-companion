import 'package:flutter/services.dart';
import '../../../../core/utils/logger.dart';

/// Bridges to [QiblaMethodChannelHandler] on Android for real magnetic
/// declination (via `android.hardware.GeomagneticField`, backed by the
/// NOAA World Magnetic Model). There's no equivalent call on iOS — this
/// resolves to null there, and callers fall back to an uncorrected
/// (magnetic-only) heading rather than failing outright.
class QiblaNativeChannel {
  QiblaNativeChannel._();

  static const _channel = MethodChannel('com.devsouq.deen_companion.app/qibla');

  static Future<double?> getMagneticDeclination({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final result = await _channel.invokeMethod<double>(
        'getMagneticDeclination',
        {'latitude': latitude, 'longitude': longitude},
      );
      return result;
    } catch (error) {
      AppLogger.e('Qibla: magnetic declination lookup failed', error);
      return null;
    }
  }
}
