import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_status.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/logger.dart';

/// What the header should show next to the greeting. Modelled explicitly
/// rather than as a bare String so the UI can tell "still working on it"
/// apart from "we can't, and here's the fix" — the old version collapsed
/// every outcome into a string and left the header stuck on "Locating…"
/// whenever a platform call never returned.
sealed class LocationLabel {
  const LocationLabel();
}

class LocationLabelResolved extends LocationLabel {
  final String name;

  /// Derived from stored coordinates rather than a live fix.
  final bool isApproximate;

  const LocationLabelResolved(this.name, {this.isApproximate = false});
}

class LocationLabelUnavailable extends LocationLabel {
  final LocationErrorKind kind;
  const LocationLabelUnavailable(this.kind);
}

const _cachedNameKey = 'last_known_location_name';

/// Reverse-geocodes the current coordinates into a city/country label.
///
/// Every step is bounded and every failure is a value, so this provider
/// always settles: it can't leave the greeting header spinning.
final currentLocationNameProvider = FutureProvider<LocationLabel>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  final storage = ref.watch(localStorageServiceProvider);

  Coordinates coordinates;
  try {
    coordinates = await locationService.getCurrentCoordinates();
  } on LocationServiceException catch (e) {
    // Show the last place we knew about rather than nothing at all, but keep
    // the label marked approximate.
    final cachedName = storage.get<String>(
      AppConstants.settingsBoxName,
      _cachedNameKey,
    );
    if (cachedName != null && cachedName.isNotEmpty) {
      return LocationLabelResolved(cachedName, isApproximate: true);
    }
    return LocationLabelUnavailable(e.kind);
  }

  // Reverse geocoding needs Play Services / network and is the single most
  // common thing to hang here, so it gets its own budget and falls back to
  // the raw coordinates instead of failing the whole label.
  try {
    final placemarks = await placemarkFromCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    ).timeout(const Duration(seconds: 8));

    final name = _formatPlacemarks(placemarks);
    if (name != null) {
      await storage.put(AppConstants.settingsBoxName, _cachedNameKey, name);
      return LocationLabelResolved(name, isApproximate: coordinates.isStale);
    }
  } catch (error) {
    AppLogger.e('Reverse geocoding failed', error);
  }

  final cachedName = storage.get<String>(
    AppConstants.settingsBoxName,
    _cachedNameKey,
  );
  if (cachedName != null && cachedName.isNotEmpty) {
    return LocationLabelResolved(cachedName, isApproximate: true);
  }

  return LocationLabelResolved(
    _formatCoordinates(coordinates),
    isApproximate: true,
  );
});

String? _formatPlacemarks(List<Placemark> placemarks) {
  if (placemarks.isEmpty) return null;

  final place = placemarks.first;
  final city = (place.locality?.isNotEmpty ?? false)
      ? place.locality!
      : (place.subAdministrativeArea ?? '');
  final country = place.country ?? '';

  if (city.isEmpty && country.isEmpty) return null;
  if (city.isEmpty) return country;
  if (country.isEmpty) return city;
  return '$city, $country';
}

String _formatCoordinates(Coordinates coordinates) {
  final lat = coordinates.latitude.toStringAsFixed(2);
  final lng = coordinates.longitude.toStringAsFixed(2);
  return '$lat, $lng';
}
