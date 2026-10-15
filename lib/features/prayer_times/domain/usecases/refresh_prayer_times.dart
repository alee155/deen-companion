import '../../../../core/error/failures.dart';
import '../../../../core/location/geo_distance.dart';
import '../../../../core/location/location_service.dart';
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

  @override
  Future<Result<RefreshPrayerTimesResult>> call(RefreshPrayerTimesParams p) =>
      p.isSignedIn ? _signedIn(p) : _guest(p);

  Future<Result<RefreshPrayerTimesResult>> _guest(
    RefreshPrayerTimesParams p,
  ) async {
    final send = MethodSendRule.resolve(
      chosenMethod: p.chosenMethod,
      chosenSchool: p.chosenSchool,
      countryCode: p.countryCode,
    );
    final result = await repository.fetchGuestTimes(
      p.coordinates,
      method: send.method,
      school: send.school,
      days: days,
    );
    return result.when(
      success: (bundle) => Success(
        RefreshPrayerTimesResult(
          bundle: bundle,
          // Unverified Aladhan times say nothing about the user's settings.
          adoptSettings: !bundle.isUnverified,
          settingsApplied: !bundle.isUnverified,
        ),
      ),
      failure: (f) => Error(f),
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
        return _guest(p);
      }
      return Error(failure);
    }
    final settings = (saved as Success<SavedPrayerSettings>).data;

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
      final send = MethodSendRule.resolve(
        chosenMethod: p.chosenMethod,
        chosenSchool: p.chosenSchool,
        countryCode: p.countryCode,
      );
      syncFailure = await put(
        p.coordinates,
        method: send.method,
        school: send.school,
      );
      settingsApplied = syncFailure == null;
    } else if (p.settingsChanged && settings.method != null) {
      // The user changed method or school: resend the same place with both
      // values, so nothing else about the account's choice is lost.
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
      syncFailure = await put(p.coordinates);
    }

    if (syncFailure != null) return Error(syncFailure);

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
      success: (bundle) => Success(
        RefreshPrayerTimesResult(
          bundle: PrayerTimesBundle(
            location: bundle.location,
            method: bundle.method,
            days: bundle.days,
            lockedDates: locked,
          ),
          settingsApplied: settingsApplied,
        ),
      ),
      failure: (f) => Error(f),
    );
  }

  static bool _unreachable(Object failure) => failure is PrayerTimesFailure
      ? (failure.statusCode ?? 0) >= 500
      : failure.runtimeType.toString() == 'NetworkFailure';
}
