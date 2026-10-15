import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/device/device_id_store.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../data/datasources/aladhan_fallback_datasource.dart';
import '../../data/datasources/prayer_times_remote_datasource.dart';
import '../../data/repositories/prayer_times_repository_impl.dart';
import '../../domain/entities/prayer_calculation_settings.dart';
import '../../domain/entities/prayer_times_bundle.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../../domain/usecases/refresh_prayer_times.dart';
import 'manual_city_provider.dart';
import 'prayer_calculation_settings_provider.dart';

final prayerTimesRemoteDataSourceProvider =
    Provider<PrayerTimesRemoteDataSource>(
      (ref) => PrayerTimesRemoteDataSourceImpl(
        ref.watch(dioProvider),
        deviceId: ref.watch(deviceIdStoreProvider).get,
      ),
    );

final aladhanFallbackDataSourceProvider = Provider<AladhanFallbackDataSource>(
  (ref) => AladhanFallbackDataSourceImpl(ref.watch(dioProvider)),
);

final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>(
  (ref) => PrayerTimesRepositoryImpl(
    remote: ref.watch(prayerTimesRemoteDataSourceProvider),
    fallback: ref.watch(aladhanFallbackDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final refreshPrayerTimesProvider = Provider<RefreshPrayerTimes>(
  (ref) => RefreshPrayerTimes(ref.watch(prayerTimesRepositoryProvider)),
);

/// Where prayer times are for: the picked city, or the device location, plus
/// the country when it is known.
class PrayerPlace {
  final Coordinates coordinates;
  final String? countryCode;

  /// Set when the user picked a city rather than sharing their location.
  final PrayerCity? city;

  const PrayerPlace({required this.coordinates, this.countryCode, this.city});
}

/// Goes up each time a refresh brought prayer times that differ from what was
/// cached (new location, new method or school, the server recalculated, a
/// different account). Everything armed from prayer times — reminders, Do Not
/// Disturb, the daily notification — listens to this and re-arms, so a
/// schedule never stays built on times that have since changed.
final prayerTimesUpdatedProvider = StateProvider<int>((ref) => 0);

/// Raised after a method/school change when some days could not change
/// because a prayer is already logged on them. The screen shows a short
/// notice and resets it.
final lockedDatesNoticeProvider = StateProvider<List<String>>(
  (ref) => const [],
);

/// The one way prayer times are brought up to date: resolves the place, runs
/// [RefreshPrayerTimes], and applies the outcome (adopting the server's
/// settings, noting locked days). The home header, reminders, Do Not Disturb
/// and the log flow all go through here, so they never repeat a request.
class PrayerTimesLoader {
  final Ref ref;
  PrayerTimesLoader(this.ref);

  Future<Result<PrayerTimesBundle>>? _inFlight;

  /// Fetches (or joins the fetch already running). A fetch that is waiting on
  /// a pending settings change is never skipped: [force] starts a new one.
  Future<Result<PrayerTimesBundle>> refresh({bool force = false}) {
    final running = _inFlight;
    if (running != null && !force) {
      FlowLog.log(
        _tag,
        'REFRESH ALREADY RUNNING -> JOINING IT (no second request)',
      );
      return running;
    }
    FlowLog.log(_tag, force ? 'REFRESH STARTED (forced)' : 'REFRESH STARTED');
    final next = _run().whenComplete(() => _inFlight = null);
    return _inFlight = next;
  }

  static const _tag = 'PRAYER TIMES';

  Future<Result<PrayerTimesBundle>> _run() async {
    final PrayerPlace place;
    try {
      place = await resolvePlace();
    } on LocationFailure catch (f) {
      FlowLog.error(_tag, 'NO LOCATION AVAILABLE (${f.kind.name})', f.message);
      return Error(f);
    }
    FlowLog.data(_tag, 'STEP 1 - place resolved', {
      'source': place.city != null
          ? 'picked city: ${place.city!.name}'
          : 'device location',
      'latitude': place.coordinates.latitude,
      'longitude': place.coordinates.longitude,
      'country': place.countryCode ?? 'unknown',
    });

    final settings = ref.read(prayerCalculationSettingsProvider.notifier);
    final choice = settings.choice;
    final signedIn = ref.read(authSessionProvider).isAuthenticated;
    // What the cache held before, to tell afterwards whether anything changed.
    final before = ref.read(prayerTimesRepositoryProvider).getCachedBundle();
    FlowLog.data(_tag, 'STEP 2 - who and what the user chose', {
      'signedIn': signedIn,
      'chosenMethod': choice.methodId ?? 'not chosen',
      'chosenSchool': choice.schoolId ?? 'not chosen',
      'changeNotSentYet': choice.changedByUser,
    });

    final result = await ref
        .read(refreshPrayerTimesProvider)
        .call(
          RefreshPrayerTimesParams(
            isSignedIn: signedIn,
            coordinates: place.coordinates,
            countryCode: place.countryCode,
            chosenMethod: choice.methodId,
            chosenSchool: choice.schoolId,
            settingsChanged: choice.changedByUser,
          ),
        );

    return result.when(
      success: (r) async {
        FlowLog.log(
          _tag,
          'STEP 3 - TIMES RECEIVED: ${r.bundle.days.length} days'
          '${r.bundle.isUnverified ? ' (UNVERIFIED Aladhan fallback)' : ''}',
        );
        if (r.adoptSettings) {
          FlowLog.data(_tag, 'adopting the server settings', {
            'method': '${r.bundle.method.id} ${r.bundle.method.name}',
            'school': r.bundle.method.school,
          });
          await settings.adopt(
            methodId: r.bundle.method.id,
            schoolId: r.bundle.method.schoolId,
          );
        }
        if (r.settingsApplied) {
          await settings.markSynced();
          if (choice.changedByUser && r.bundle.lockedDates.isNotEmpty) {
            FlowLog.data(
              _tag,
              'SOME DAYS WERE LOCKED (a prayer is already logged) - showing the notice',
              r.bundle.lockedDates,
            );
            ref.read(lockedDatesNoticeProvider.notifier).state =
                r.bundle.lockedDates;
          }
        }
        _announceIfChanged(before, r.bundle);
        return Success(r.bundle);
      },
      failure: (f) async {
        FlowLog.error(_tag, 'REFRESH FAILED', f.message);
        return Error(f);
      },
    );
  }

  /// Tells reminders, Do Not Disturb and the daily notification that the times
  /// they were armed from have changed.
  void _announceIfChanged(PrayerTimesBundle? before, PrayerTimesBundle after) {
    final changed = before == null || !listEquals(before.days, after.days);
    FlowLog.log(
      _tag,
      changed
          ? 'TIMES CHANGED (${before == null ? 'nothing cached before' : 'differ from the cache'}) '
                '-> TELLING REMINDERS, DND AND THE DAILY NOTIFICATION TO RE-ARM'
          : 'TIMES UNCHANGED -> alarms stay as they are',
    );
    if (changed) ref.read(prayerTimesUpdatedProvider.notifier).state++;
  }

  /// The picked city, else the device location (throws [LocationFailure]).
  Future<PrayerPlace> resolvePlace() async {
    final city = ref.read(manualCityProvider);
    if (city != null) {
      FlowLog.log(_tag, 'USING THE PICKED CITY: ${city.label} (GPS not asked)');
      return PrayerPlace(
        coordinates: Coordinates(
          latitude: city.latitude,
          longitude: city.longitude,
        ),
        countryCode: city.countryCode,
        city: city,
      );
    }
    FlowLog.log(_tag, 'ASKING THE DEVICE FOR ITS LOCATION');
    final Coordinates coordinates;
    try {
      coordinates = await ref
          .read(locationServiceProvider)
          .getCurrentCoordinates();
    } on LocationServiceException catch (e) {
      throw LocationFailure(e.kind, e.message);
    }
    return PrayerPlace(
      coordinates: coordinates,
      countryCode: await _countryCode(),
    );
  }

  Future<String?> _countryCode() async {
    final quick = ref.read(quickCountryProvider);
    if (quick != null) return quick;
    try {
      return await ref
          .read(deviceCountryCodeProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null; // unknown: the server default applies
    }
  }
}

final prayerTimesLoaderProvider = Provider<PrayerTimesLoader>((ref) {
  // Signing out drops the cached days: they were fetched for the account, and
  // the next owner of the phone (or the same person as a guest) must not be
  // shown them. The picked city and the settings stay; they belong to the
  // device.
  ref.listen<bool>(authSessionProvider.select((s) => s.isAuthenticated), (
    wasSignedIn,
    isSignedIn,
  ) {
    if (wasSignedIn == true && !isSignedIn) {
      unawaited(ref.read(prayerTimesRepositoryProvider).clearCache());
    }
  });
  return PrayerTimesLoader(ref);
});

/// A calculation method as shown in the settings list.
typedef MethodChoiceOption = ({PrayerCalculationMethod method, String label});

/// The methods to offer: the server's list (`GET /prayer-times/methods`) in
/// its own order and wording, so the app never offers an id the server
/// rejects. Offline, the built-in list stands in.
final prayerMethodOptionsProvider = FutureProvider<List<MethodChoiceOption>>((
  ref,
) async {
  final builtIn = [
    for (final m in PrayerCalculationMethod.values) (method: m, label: m.label),
  ];
  final result = await ref.read(prayerTimesRepositoryProvider).getMethods();
  return result.when(
    success: (options) {
      final fromServer = <MethodChoiceOption>[];
      for (final o in options) {
        for (final m in PrayerCalculationMethod.values) {
          if (m.id == o.id) {
            fromServer.add((
              method: m,
              label: o.name.isEmpty ? m.label : o.name,
            ));
          }
        }
      }
      return fromServer.isEmpty ? builtIn : fromServer;
    },
    failure: (_) => builtIn,
  );
});
