import 'package:deen_companion/core/location/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

/// Reverse-geocodes the device's current coordinates into a human city/
/// country string. Falls back gracefully — never throws into the UI —
/// since geocoding can fail on emulators without Play services, or when
/// offline.
final currentLocationNameProvider = FutureProvider<String>((ref) async {
  try {
    final locationService = ref.watch(locationServiceProvider);
    final coordinates = await locationService.getCurrentCoordinates();
    final placemarks = await placemarkFromCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (placemarks.isEmpty) return 'Location unavailable';

    final place = placemarks.first;
    final city = (place.locality?.isNotEmpty ?? false)
        ? place.locality!
        : (place.subAdministrativeArea ?? '');
    final country = place.country ?? '';

    if (city.isEmpty && country.isEmpty) return 'Location unavailable';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  } catch (_) {
    return 'Location unavailable';
  }
});
