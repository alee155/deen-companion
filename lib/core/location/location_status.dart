/// Why a location read failed. The UI needs this — "location services are
/// switched off" and "we couldn't reach the network" call for completely
/// different prompts, and lumping them together is what produced the
/// "You're offline. Check your connection." message on a device whose only
/// problem was a disabled GPS toggle.
enum LocationErrorKind {
  /// Device-wide Location Services toggle is off. Fixed in system settings,
  /// not by an in-app permission prompt.
  serviceDisabled,

  /// The app's location permission was denied, but can be asked again.
  permissionDenied,

  /// Denied permanently ("Don't ask again") — only the app settings page
  /// can change it now.
  permissionDeniedForever,

  /// Permission and services are fine, but no fix arrived in time.
  timeout,

  /// Anything else the platform threw at us.
  unavailable,
}

extension LocationErrorKindX on LocationErrorKind {
  /// Whether showing an in-app "Allow" prompt can still resolve this.
  bool get isRequestable => this == LocationErrorKind.permissionDenied;

  /// Whether the fix lives in the system settings app.
  bool get needsSystemSettings =>
      this == LocationErrorKind.serviceDisabled ||
      this == LocationErrorKind.permissionDeniedForever;

  String get userMessage => switch (this) {
    LocationErrorKind.serviceDisabled =>
      'Location Services are turned off on this device. Turn them on so '
          'prayer times and Qibla can be calculated for where you are.',
    LocationErrorKind.permissionDenied =>
      'Deen needs your location to calculate accurate prayer times and the '
          'Qibla direction.',
    LocationErrorKind.permissionDeniedForever =>
      'Location permission is blocked for Deen. Enable it in app settings to '
          'get prayer times for your area.',
    LocationErrorKind.timeout =>
      "Couldn't get a location fix. Move somewhere with a clearer signal, or "
          'try again.',
    LocationErrorKind.unavailable =>
      "Couldn't read your location on this device.",
  };

  /// Short label for the action that resolves it.
  String get actionLabel => switch (this) {
    LocationErrorKind.serviceDisabled => 'Open location settings',
    LocationErrorKind.permissionDenied => 'Allow location',
    LocationErrorKind.permissionDeniedForever => 'Open app settings',
    LocationErrorKind.timeout => 'Try again',
    LocationErrorKind.unavailable => 'Try again',
  };
}

/// Snapshot of everything the UI needs to decide whether to nag the user.
class LocationAvailability {
  final bool serviceEnabled;
  final bool hasPermission;
  final bool permanentlyDenied;

  const LocationAvailability({
    required this.serviceEnabled,
    required this.hasPermission,
    required this.permanentlyDenied,
  });

  bool get isUsable => serviceEnabled && hasPermission;

  LocationErrorKind? get errorKind {
    if (!serviceEnabled) return LocationErrorKind.serviceDisabled;
    if (permanentlyDenied) return LocationErrorKind.permissionDeniedForever;
    if (!hasPermission) return LocationErrorKind.permissionDenied;
    return null;
  }
}
