import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/prayer_times_bundle.dart';

/// The city the user picked instead of sharing their location. While one is
/// set, prayer times are for that city; clearing it goes back to GPS.
class ManualCityNotifier extends Notifier<PrayerCity?> {
  static const _key = 'prayer_manual_city';

  @override
  PrayerCity? build() {
    final raw = ref
        .read(localStorageServiceProvider)
        .get<Map>(AppConstants.settingsBoxName, _key);
    if (raw == null) return null;
    try {
      return PrayerCity(
        name: raw['name'] as String,
        region: raw['region'] as String? ?? '',
        country: raw['country'] as String? ?? '',
        countryCode: raw['countryCode'] as String? ?? '',
        latitude: (raw['latitude'] as num).toDouble(),
        longitude: (raw['longitude'] as num).toDouble(),
        timezone: raw['timezone'] as String? ?? '',
      );
    } catch (_) {
      return null; // a damaged entry is the same as no choice
    }
  }

  Future<void> select(PrayerCity city) async {
    state = city;
    await ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, _key, {
          'name': city.name,
          'region': city.region,
          'country': city.country,
          'countryCode': city.countryCode,
          'latitude': city.latitude,
          'longitude': city.longitude,
          'timezone': city.timezone,
        });
  }

  /// Back to the device location.
  Future<void> clear() async {
    state = null;
    await ref
        .read(localStorageServiceProvider)
        .delete(AppConstants.settingsBoxName, _key);
  }
}

final manualCityProvider = NotifierProvider<ManualCityNotifier, PrayerCity?>(
  ManualCityNotifier.new,
);
