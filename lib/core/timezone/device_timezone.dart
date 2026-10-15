import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../utils/logger.dart';

/// The device's IANA timezone name (`Asia/Karachi`), which is what the
/// backend stores and validates — never a bare offset like `+05:00`.
abstract class DeviceTimezone {
  /// Null when the platform can't say or returns something that isn't an IANA
  /// name; callers then skip timezone work rather than send a bad value.
  Future<String?> iana();
}

class FlutterDeviceTimezone implements DeviceTimezone {
  const FlutterDeviceTimezone();

  @override
  Future<String?> iana() async {
    try {
      final id = (await FlutterTimezone.getLocalTimezone()).identifier.trim();
      return looksLikeIana(id) ? id : null;
    } catch (e, st) {
      AppLogger.e('DeviceTimezone: could not read the device timezone', e, st);
      return null;
    }
  }

  /// `Area/Location` (`Asia/Karachi`, `America/Argentina/Buenos_Aires`) or
  /// `UTC`. Rejects abbreviations such as `PKT` or `GMT+5`.
  static bool looksLikeIana(String id) =>
      id == 'UTC' || RegExp(r'^[A-Za-z_]+(/[A-Za-z0-9_+\-]+)+$').hasMatch(id);
}

final deviceTimezoneProvider = Provider<DeviceTimezone>(
  (ref) => const FlutterDeviceTimezone(),
);
