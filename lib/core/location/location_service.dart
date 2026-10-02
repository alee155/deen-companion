import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_constants.dart';
import '../storage/local_storage_service.dart';
import '../utils/logger.dart';
import 'location_status.dart';

class Coordinates {
  final double latitude;
  final double longitude;

  /// True when these came from a stored/last-known fix rather than a live
  /// read — callers can still use them, but may want to say "approximate".
  final bool isStale;

  const Coordinates({
    required this.latitude,
    required this.longitude,
    this.isStale = false,
  });
}

class LocationServiceException implements Exception {
  final LocationErrorKind kind;
  final String message;

  LocationServiceException(this.kind, [String? message])
    : message = message ?? kind.userMessage;

  @override
  String toString() => message;
}

abstract class LocationService {
  /// Resolves usable coordinates or throws [LocationServiceException].
  ///
  /// Never hangs: every platform call is bounded, and a live fix that doesn't
  /// arrive in time falls back to the platform's last-known position and then
  /// to the last position this app stored.
  Future<Coordinates> getCurrentCoordinates({bool requestPermission = true});

  /// Synchronous read of the last position we persisted, if any.
  Coordinates? lastStoredCoordinates();

  /// Current service/permission state, without prompting.
  Future<LocationAvailability> checkAvailability();

  /// Shows the OS permission prompt (no-op if already granted or blocked).
  Future<LocationAvailability> requestPermission();

  Future<void> openLocationSettings();

  Future<void> openAppSettings();

  /// Fires when the device-wide Location Services toggle changes. Permission
  /// changes have no platform stream, so callers also re-check on app resume.
  Stream<void> serviceStatusChanges();
}

class GeolocatorLocationService implements LocationService {
  final LocalStorageService storage;

  GeolocatorLocationService(this.storage);

  static const _latKey = 'last_known_latitude';
  static const _lngKey = 'last_known_longitude';

  /// Deliberately short. A phone that can't produce a fix in this long
  /// usually won't produce one in thirty seconds either, and the user is
  /// staring at "Locating…" for every one of those seconds.
  static const _fixTimeout = Duration(seconds: 12);
  static const _platformCallTimeout = Duration(seconds: 5);

  /// A live fix this recent is reused, so the several features that ask for
  /// a location at startup (prayer times, header label, Qibla) trigger one
  /// GPS read instead of one each.
  static const _fixFreshness = Duration(minutes: 2);

  Coordinates? _lastLiveFix;
  DateTime? _lastLiveFixAt;
  Future<Coordinates>? _inFlightWithPrompt;
  Future<Coordinates>? _inFlightSilent;
  Future<LocationAvailability>? _inFlightPermission;

  @override
  Coordinates? lastStoredCoordinates() {
    final lat = storage.get<double>(AppConstants.settingsBoxName, _latKey);
    final lng = storage.get<double>(AppConstants.settingsBoxName, _lngKey);
    if (lat == null || lng == null) return null;
    return Coordinates(latitude: lat, longitude: lng, isStale: true);
  }

  Future<void> _store(Coordinates coordinates) async {
    await storage.put(
      AppConstants.settingsBoxName,
      _latKey,
      coordinates.latitude,
    );
    await storage.put(
      AppConstants.settingsBoxName,
      _lngKey,
      coordinates.longitude,
    );
  }

  @override
  Future<LocationAvailability> checkAvailability() async {
    final serviceEnabled = await _guard(
      Geolocator.isLocationServiceEnabled,
      fallback: false,
    );
    final permission = await _guard(
      Geolocator.checkPermission,
      fallback: LocationPermission.denied,
    );

    return LocationAvailability(
      serviceEnabled: serviceEnabled,
      hasPermission:
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse,
      permanentlyDenied: permission == LocationPermission.deniedForever,
    );
  }

  /// Single-flight: the OS only allows one permission request at a time, and
  /// a second concurrent call fails with "already running" — which used to
  /// surface as a bogus "permission denied" for whichever feature lost the
  /// race on a fresh install.
  @override
  Future<LocationAvailability> requestPermission() {
    return _inFlightPermission ??= _requestPermission().whenComplete(
      () => _inFlightPermission = null,
    );
  }

  Future<LocationAvailability> _requestPermission() async {
    final current = await checkAvailability();
    if (current.hasPermission || current.permanentlyDenied) return current;

    // The system dialog waits on the user, so it must not use the short
    // platform-call timeout.
    try {
      // Generous (the user may take a while), but bounded: if the OS drops
      // the request because another permission dialog was on screen, the
      // platform future never completes, which used to leave every screen
      // waiting on location stuck on its loader.
      await Geolocator.requestPermission().timeout(const Duration(minutes: 2));
    } catch (error) {
      AppLogger.e('Location: permission request failed', error);
    }
    return checkAvailability();
  }

  @override
  Stream<void> serviceStatusChanges() =>
      Geolocator.getServiceStatusStream().map((_) {}).handleError((Object e) {
        AppLogger.e('Location: service status stream failed', e);
      });

  @override
  Future<void> openLocationSettings() async {
    await _guard(Geolocator.openLocationSettings, fallback: false);
  }

  @override
  Future<void> openAppSettings() async {
    await _guard(Geolocator.openAppSettings, fallback: false);
  }

  @override
  Future<Coordinates> getCurrentCoordinates({bool requestPermission = true}) {
    final fixedAt = _lastLiveFixAt;
    final fix = _lastLiveFix;
    if (fix != null &&
        fixedAt != null &&
        DateTime.now().difference(fixedAt) < _fixFreshness) {
      return Future.value(fix);
    }
    // Concurrent callers share one resolution (and one permission prompt).
    if (requestPermission) {
      return _inFlightWithPrompt ??= _resolve(
        requestPermission: true,
      ).whenComplete(() => _inFlightWithPrompt = null);
    }
    return _inFlightSilent ??= _resolve(
      requestPermission: false,
    ).whenComplete(() => _inFlightSilent = null);
  }

  Future<Coordinates> _resolve({required bool requestPermission}) async {
    var availability = await checkAvailability();

    if (!availability.serviceEnabled) {
      return _fallbackOrThrow(LocationErrorKind.serviceDisabled);
    }

    if (!availability.hasPermission) {
      if (availability.permanentlyDenied) {
        return _fallbackOrThrow(LocationErrorKind.permissionDeniedForever);
      }
      if (!requestPermission) {
        return _fallbackOrThrow(LocationErrorKind.permissionDenied);
      }
      availability = await this.requestPermission();
      if (!availability.hasPermission) {
        return _fallbackOrThrow(
          availability.permanentlyDenied
              ? LocationErrorKind.permissionDeniedForever
              : LocationErrorKind.permissionDenied,
        );
      }
    }

    // 1. Live fix, hard-bounded.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _fixTimeout,
        ),
      ).timeout(_fixTimeout + const Duration(seconds: 2));

      final coordinates = Coordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _lastLiveFix = coordinates;
      _lastLiveFixAt = DateTime.now();
      await _store(coordinates);
      return coordinates;
    } catch (error) {
      AppLogger.e('Location: live fix failed', error);
    }

    // 2. Whatever the OS already had cached.
    try {
      final last = await Geolocator.getLastKnownPosition().timeout(
        _platformCallTimeout,
      );
      if (last != null) {
        final coordinates = Coordinates(
          latitude: last.latitude,
          longitude: last.longitude,
          isStale: true,
        );
        await _store(coordinates);
        return coordinates;
      }
    } catch (error) {
      AppLogger.e('Location: last-known lookup failed', error);
    }

    // 3. The position this app itself last saw.
    return _fallbackOrThrow(LocationErrorKind.timeout);
  }

  /// Stale coordinates beat an error screen: prayer times for this morning's
  /// position are still close enough to be useful, and the UI surfaces the
  /// location problem separately instead of blanking the content.
  Coordinates _fallbackOrThrow(LocationErrorKind kind) {
    final stored = lastStoredCoordinates();
    if (stored != null) return stored;
    throw LocationServiceException(kind);
  }

  /// Platform channels can throw (plugin not registered yet, service missing
  /// on an emulator) — every geolocator call goes through here so a throw
  /// becomes a value instead of an unhandled async error that leaves a
  /// provider stuck in its loading state forever.
  Future<T> _guard<T>(Future<T> Function() call, {required T fallback}) async {
    try {
      return await call().timeout(_platformCallTimeout);
    } catch (error) {
      AppLogger.e('Location: platform call failed', error);
      return fallback;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService(ref.watch(localStorageServiceProvider));
});

/// Live service + permission state. Re-checked when Location Services are
/// toggled, when the app returns to the foreground (system permission
/// dialogs and the settings app both end that way), and — only while
/// location is *not* usable — on a short poll as a safety net for OEMs that
/// don't report the change. Emits only when something actually changed.
///
/// `ref.invalidate` still forces an immediate re-check (used after the app
/// itself asks for permission).
final locationAvailabilityProvider = StreamProvider<LocationAvailability>((
  ref,
) {
  final service = ref.watch(locationServiceProvider);
  final controller = StreamController<LocationAvailability>();
  LocationAvailability? last;
  Timer? poll;
  var checking = false;

  Future<void> check() async {
    if (checking || controller.isClosed) return;
    checking = true;
    try {
      final now = await service.checkAvailability();
      if (controller.isClosed) return;
      final changed =
          last == null ||
          last!.serviceEnabled != now.serviceEnabled ||
          last!.hasPermission != now.hasPermission ||
          last!.permanentlyDenied != now.permanentlyDenied;
      last = now;
      if (changed) controller.add(now);

      if (now.isUsable) {
        poll?.cancel();
        poll = null;
      } else {
        poll ??= Timer.periodic(const Duration(seconds: 2), (_) {
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) {
            check();
          }
        });
      }
    } finally {
      checking = false;
    }
  }

  final observer = _ResumeObserver(check);
  WidgetsBinding.instance.addObserver(observer);
  final statusSub = service.serviceStatusChanges().listen((_) => check());

  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    statusSub.cancel();
    poll?.cancel();
    controller.close();
  });

  check();
  return controller.stream;
});

class _ResumeObserver with WidgetsBindingObserver {
  final VoidCallback onResume;
  _ResumeObserver(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// Bumps by one each time location goes from known-unusable (services off or
/// permission missing) to usable. Location-dependent providers `watch` this,
/// so they rebuild themselves exactly when recovery happens — no screen has
/// to wire up a retry, and nothing refetches on ordinary launches.
class LocationRecoveryNotifier extends Notifier<int> {
  bool? _wasUsable;

  @override
  int build() {
    ref.listen<AsyncValue<LocationAvailability>>(locationAvailabilityProvider, (
      _,
      next,
    ) {
      final usable = next.valueOrNull?.isUsable;
      if (usable == null) return;
      if (_wasUsable == false && usable) state = state + 1;
      _wasUsable = usable;
    }, fireImmediately: true);
    return 0;
  }
}

final locationRecoveryProvider =
    NotifierProvider<LocationRecoveryNotifier, int>(
      LocationRecoveryNotifier.new,
    );

/// Performs the fix a [LocationErrorKind] calls for. Recovery afterwards is
/// automatic (see [locationRecoveryProvider]).
Future<void> resolveLocationIssue(
  LocationService service,
  LocationErrorKind kind,
) async {
  switch (kind) {
    case LocationErrorKind.serviceDisabled:
      await service.openLocationSettings();
    case LocationErrorKind.permissionDeniedForever:
      await service.openAppSettings();
    case LocationErrorKind.permissionDenied:
      final availability = await service.requestPermission();
      if (availability.permanentlyDenied) await service.openAppSettings();
    case LocationErrorKind.timeout:
    case LocationErrorKind.unavailable:
      break;
  }
}

const _countryCodeCacheKey = 'last_known_country_code';

/// A handful of countries relevant to region-specific defaults (currently
/// just the Hijri-date preference), keyed by the full country name
/// Android's geocoder reliably returns. Extend as more regions get their
/// own default.
const _countryNameToCode = {'pakistan': 'PK'};

/// Best-effort ISO 3166-1 alpha-2 country code for where the device
/// currently is (e.g. 'PK').
///
/// Used exactly once per install, to pick a sensible *initial default*
/// for the Hijri-date preference (see HijriAdjustmentNotifier) — not for
/// any ongoing correction. Never throws and never prompts for permission
/// itself: resolves to null if location isn't already available, and
/// falls back to the last cached value rather than making a fresh
/// network call every time.
final deviceCountryCodeProvider = FutureProvider<String?>((ref) async {
  ref.watch(locationRecoveryProvider);
  final storage = ref.watch(localStorageServiceProvider);

  try {
    final coordinates = await ref
        .watch(locationServiceProvider)
        .getCurrentCoordinates(requestPermission: false);

    final placemarks = await placemarkFromCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    ).timeout(const Duration(seconds: 8));

    // Android's geocoder frequently leaves isoCountryCode empty even when
    // it correctly resolves the full country name — so isoCountryCode is
    // tried first (it's the more precise signal when present), and the
    // name is used as the fallback rather than being treated as a failure.
    final place = placemarks.isNotEmpty ? placemarks.first : null;
    final isoCode = place?.isoCountryCode;
    final code = (isoCode != null && isoCode.isNotEmpty)
        ? isoCode
        : _countryNameToCode[place?.country?.trim().toLowerCase()];

    if (code != null && code.isNotEmpty) {
      await storage.put(
        AppConstants.settingsBoxName,
        _countryCodeCacheKey,
        code,
      );
      return code;
    }
  } catch (error) {
    AppLogger.e('Device country-code lookup failed', error);
  }

  return storage.get<String>(
    AppConstants.settingsBoxName,
    _countryCodeCacheKey,
  );
});
