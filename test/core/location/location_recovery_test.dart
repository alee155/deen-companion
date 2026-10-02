import 'dart:async';

import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService implements LocationService {
  LocationAvailability availability;
  final status = StreamController<void>.broadcast();

  _FakeLocationService(this.availability);

  @override
  Future<LocationAvailability> checkAvailability() async => availability;

  @override
  Stream<void> serviceStatusChanges() => status.stream;

  @override
  Future<Coordinates> getCurrentCoordinates({bool requestPermission = true}) =>
      throw UnimplementedError();

  @override
  Coordinates? lastStoredCoordinates() => null;

  @override
  Future<LocationAvailability> requestPermission() async => availability;

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openAppSettings() async {}
}

const _off = LocationAvailability(
  serviceEnabled: false,
  hasPermission: true,
  permanentlyDenied: false,
);
const _noPermission = LocationAvailability(
  serviceEnabled: true,
  hasPermission: false,
  permanentlyDenied: false,
);
const _on = LocationAvailability(
  serviceEnabled: true,
  hasPermission: true,
  permanentlyDenied: false,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer make(_FakeLocationService service) {
    final container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    // Keep the provider alive like a watching dependent would.
    container.listen(locationRecoveryProvider, (_, _) {});
    return container;
  }

  test('bumps once when Location Services go from off to on', () async {
    final service = _FakeLocationService(_off);
    final container = make(service);
    await _settle();
    expect(container.read(locationRecoveryProvider), 0);

    service.availability = _on;
    service.status.add(null);
    await _settle();
    expect(container.read(locationRecoveryProvider), 1);
  });

  test('bumps when permission is granted', () async {
    final service = _FakeLocationService(_noPermission);
    final container = make(service);
    await _settle();

    service.availability = _on;
    service.status.add(null);
    await _settle();
    expect(container.read(locationRecoveryProvider), 1);
  });

  test('a normal launch with location already on never bumps', () async {
    final service = _FakeLocationService(_on);
    final container = make(service);
    await _settle();
    service.status.add(null);
    await _settle();
    expect(container.read(locationRecoveryProvider), 0);
  });

  test('turning location off does not bump', () async {
    final service = _FakeLocationService(_on);
    final container = make(service);
    await _settle();
    service.availability = _off;
    service.status.add(null);
    await _settle();
    expect(container.read(locationRecoveryProvider), 0);
  });
}
