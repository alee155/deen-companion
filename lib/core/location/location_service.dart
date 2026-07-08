import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Coordinates {
  final double latitude;
  final double longitude;
  const Coordinates({required this.latitude, required this.longitude});
}

class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);
}

abstract class LocationService {
  Future<Coordinates> getCurrentCoordinates();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<Coordinates> getCurrentCoordinates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException('Location services are turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission permanently denied. Enable it from settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );

    return Coordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});
