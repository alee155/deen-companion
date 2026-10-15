import '../../../../core/error/failures.dart';
import '../../../../core/location/geo_distance.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/prayer_times_bundle.dart';
import '../method_send_rule.dart';
import '../prayer_times_failure.dart';
import '../repositories/prayer_times_repository.dart';

class RefreshPrayerTimesParams {
  final bool isSignedIn;

  /// Where the user is now (GPS) or the city they picked.
  final Coordinates coordinates;

  /// ISO country of [coordinates], when known. Decides the method rule.
  final String? countryCode;

  /// The user's chosen method and school, when they have chosen.
  final int? chosenMethod;
  final int? chosenSchool;

  /// The user changed method or school and the server has not heard yet.
  final bool settingsChanged;

  const RefreshPrayerTimesParams({
    required this.isSignedIn,
    required this.coordinates,
    this.countryCode,
    this.chosenMethod,
    this.chosenSchool,
    this.settingsChanged = false,
  });
}

class RefreshPrayerTimesResult {
  final PrayerTimesBundle bundle;

  /// The method and school in [bundle] are the truth for this account or
  /// request: the app should show (and remember) them.
  final bool adoptSettings;

  /// A pending settings change reached the server.
  final bool settingsApplied;

  const RefreshPrayerTimesResult({
    required this.bundle,
    this.adoptSettings = true,
    this.settingsApplied = false,
  });
}

/// Brings the app's prayer times up to date and returns up to 31 days.
///
/// Guests ask the public endpoint. Signed-in users keep their location on the
/// server: it is sent the first time, on a real move (over [moveThresholdKm])
/// or when the user changes method/school, and otherwise left alone, so the
/// account's saved choice wins on a new phone.
class RefreshPrayerTimes
    implements UseCase<RefreshPrayerTimesResult, RefreshPrayerTimesParams> {
  final PrayerTimesRepository repository;
  const RefreshPrayerTimes(this.repository);

  static const moveThresholdKm = 10.0;
  static const days = 31;

  static const _tag = 'USE CASE';

  @override
  Future<Result<RefreshPrayerTimesResult>> call(RefreshPrayerTimesParams p) {
    FlowLog.log(
      _tag,
      'DECIDING HOW TO GET TIMES  '
      '${p.isSignedIn ? 'signed-in account' : 'guest'}',
    );
    FlowLog.data(_tag, 'inputs', {
      'place': '${p.coordinates.latitude}, ${p.coordinates.longitude}',
      'country': p.countryCode ?? 'unknown',
      'chosenMethod': p.chosenMethod ?? 'not chosen',
      'chosenSchool': p.chosenSchool ?? 'not chosen',
      'changedByUser': p.settingsChanged,
    });
    return p.isSignedIn ? _signedIn(p) : _guest(p);
  }

  Future<Result<RefreshPrayerTimesResult>> _guest(
    RefreshPrayerTimesParams p,
  ) async {
    final send = MethodSendRule.resolve(
      chosenMethod: p.chosenMethod,
      chosenSchool: p.chosenSchool,
      countryCode: p.countryCode,
    );
    FlowLog.data(_tag, 'guest: method/school to send', {
      'method': send.method ?? 'omit (server default)',
      'school': send.school ?? 'omit (server default)',
    });
    final result = await repository.fetchGuestTimes(
      p.coordinates,
      method: send.method,
      school: send.school,
      days: days,
    );
    return result.when(
      success: (bundle) {
        FlowLog.data(_tag, 'DONE (guest)', {
          'days': bundle.days.length,
          'unverifiedAladhanFallback': bundle.isUnverified,
        });
        return Success(
          RefreshPrayerTimesResult(
            bundle: bundle,
            // Unverified Aladhan times say nothing about the user's settings.
            adoptSettings: !bundle.isUnverified,
            settingsApplied: !bundle.isUnverified,
          ),
        );
      },
      failure: (f) {
        FlowLog.error(_tag, 'GUEST FETCH FAILED', f.message);
        return Error(f);
      },
    );
  }

  Future<Result<RefreshPrayerTimesResult>> _signedIn(
    RefreshPrayerTimesParams p,
  ) async {
    final saved = await repository.getSavedSettings();
    if (saved case Error(:final failure)) {
      // The server can't be asked: with a cache the screen keeps it; with
      // none, the guest path ends in the last-resort Aladhan fallback.
      if (repository.getCachedBundle() == null && _unreachable(failure)) {
        FlowLog.log(
          _tag,
          'SERVER UNREACHABLE AND NOTHING CACHED -> GUEST PATH (Aladhan fallback)',
        );
        return _guest(p);
      }
      FlowLog.error(_tag, 'COULD NOT READ SAVED SETTINGS', failure.message);
      return Error(failure);
    }
    final settings = (saved as Success<SavedPrayerSettings>).data;
    FlowLog.data(
      _tag,
      'account has a saved location',
      settings.location != null,
    );

    List<String> locked = const [];
    var settingsApplied = false;

    /// Sends the location; remembers the locked dates the response lists.
    Future<Failure?> put(Coordinates at, {int? method, int? school}) async {
      final r = await repository.putLocation(
        at,
        method: method,
        school: school,
      );
      return r.when(
        success: (b) {
          locked = b.lockedDates;
          return null;
        },
        failure: (f) => f,
      );
    }

    final savedLocation = settings.location;
    Failure? syncFailure;

    if (savedLocation == null) {
      // First time on this account.
      FlowLog.log(_tag, 'FIRST TIME ON THIS ACCOUNT -> PUT /prayers/location');
      final send = MethodSendRule.resolve(
        chosenMethod: p.chosenMethod,
        chosenSchool: p.chosenSchool,
        countryCode: p.countryCode,
      );
      FlowLog.data(_tag, 'method/school to send', {
        'method': send.method ?? 'omit (server default)',
        'school': send.school ?? 'omit (server default)',
      });
      syncFailure = await put(
        p.coordinates,
        method: send.method,
        school: send.school,
      );
      settingsApplied = syncFailure == null;
    } else if (p.settingsChanged && settings.method != null) {
      // The user changed method or school: resend the same place with both
      // values, so nothing else about the account's choice is lost.
      FlowLog.log(
        _tag,
        'USER CHANGED METHOD/SCHOOL -> PUT /prayers/location (same place, new values)',
      );
      syncFailure = await put(
        Coordinates(
          latitude: savedLocation.latitude,
          longitude: savedLocation.longitude,
        ),
        method: p.chosenMethod ?? settings.method!.id,
        school: p.chosenSchool ?? settings.method!.schoolId,
      );
      settingsApplied = syncFailure == null;
    } else if (distanceKm(
          p.coordinates.latitude,
          p.coordinates.longitude,
          savedLocation.latitude,
          savedLocation.longitude,
        ) >
        moveThresholdKm) {
      // A real move or another city. Method and school stay as saved.
      FlowLog.log(
        _tag,
        'MOVED OVER ${moveThresholdKm.toStringAsFixed(0)} KM -> PUT /prayers/location (new place only)',
      );
      syncFailure = await put(p.coordinates);
    } else {
      FlowLog.log(
        _tag,
        'SAME PLACE, NO USER CHANGE -> NOTHING TO SEND, the saved choice is kept',
      );
    }

    if (syncFailure != null) {
      FlowLog.error(_tag, 'SENDING THE LOCATION FAILED', syncFailure.message);
      return Error(syncFailure);
    }

    var times = await repository.fetchAccountTimes(days: days);

    // The account lost its location meanwhile (cleared elsewhere): set it
    // again and retry once.
    if (times case Error(:final failure)
        when failure is PrayerTimesFailure &&
            failure.code == PrayerTimesErrorCode.locationNotSet) {
      final send = MethodSendRule.resolve(
        chosenMethod: p.chosenMethod,
        chosenSchool: p.chosenSchool,
        countryCode: p.countryCode,
      );
      FlowLog.log(
        _tag,
        'SERVER SAID LOCATION_NOT_SET -> SENDING THE LOCATION AGAIN (retry once)',
      );
      final resetFailure = await put(
        p.coordinates,
        method: send.method,
        school: send.school,
      );
      if (resetFailure != null) return Error(resetFailure);
      settingsApplied = true;
      times = await repository.fetchAccountTimes(days: days);
    }

    return times.when(
      success: (bundle) {
        FlowLog.data(_tag, 'DONE (account)', {
          'days': bundle.days.length,
          'method': bundle.method.name,
          'school': bundle.method.school,
          'timezone': bundle.location.timezone,
          'lockedDates': locked,
          'settingsApplied': settingsApplied,
        });
        return Success(
          RefreshPrayerTimesResult(
            bundle: PrayerTimesBundle(
              location: bundle.location,
              method: bundle.method,
              days: bundle.days,
              lockedDates: locked,
            ),
            settingsApplied: settingsApplied,
          ),
        );
      },
      failure: (f) {
        FlowLog.error(_tag, 'READING THE 31 DAYS FAILED', f.message);
        return Error(f);
      },
    );
  }

  /// The server, not the request, is the problem.
  static bool _unreachable(Failure failure) =>
      failure is NetworkFailure ||
      (failure is PrayerTimesFailure && (failure.statusCode ?? 0) >= 500);
}
