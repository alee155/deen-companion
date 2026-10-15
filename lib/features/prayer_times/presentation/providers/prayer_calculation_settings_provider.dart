import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/location/location_service.dart';
import '../../domain/entities/prayer_calculation_settings.dart';

/// A country code known without any permission or network — a Pakistani
/// device timezone (PKT) means Pakistan. Null when the timezone says
/// nothing. A provider so tests don't depend on the machine's timezone.
final quickCountryProvider = Provider<String?>(
  (ref) => DateTime.now().timeZoneName == 'PKT' ? 'PK' : null,
);

/// Method and Asr school, chosen by the user.
///
/// Until the user picks one, it follows where the device is: in Pakistan the
/// defaults are Karachi (University of Islamic Sciences) and Hanafi Asr;
/// anywhere else, or when the country is unknown, Muslim World League and
/// Shafi. The regional default is saved the moment it is known, through the
/// same path as a manual choice, so it never silently changes later. Each of
/// the two settings is handled on its own: someone who only picked Hanafi
/// still gets the regional method.
class PrayerCalculationSettingsNotifier
    extends Notifier<PrayerCalculationSettings> {
  static const _methodKey = 'prayer_calculation_method';
  static const _schoolKey = 'prayer_asr_school';

  bool _disposed = false;

  @override
  PrayerCalculationSettings build() {
    ref.onDispose(() => _disposed = true);
    final storage = ref.read(localStorageServiceProvider);

    final storedMethodId = storage.get<int>(
      AppConstants.settingsBoxName,
      _methodKey,
    );
    final storedSchoolId = storage.get<int>(
      AppConstants.settingsBoxName,
      _schoolKey,
    );

    PrayerCalculationMethod? method;
    for (final m in PrayerCalculationMethod.values) {
      if (m.id == storedMethodId) {
        method = m;
        break;
      }
    }
    AsrSchool? school;
    for (final s in AsrSchool.values) {
      if (s.id == storedSchoolId) {
        school = s;
        break;
      }
    }

    if (method == null || school == null) {
      // The timezone answers instantly, so a Pakistani user never sees (or
      // fetches) the world defaults first.
      if (ref.read(quickCountryProvider) == 'PK') {
        method ??= PrayerCalculationSettings.pakistan.method;
        school ??= PrayerCalculationSettings.pakistan.school;
        Future.microtask(() => _applyPakistanDefaults(updateState: false));
      } else {
        Future.microtask(_resolveFromLocation);
      }
    }

    return PrayerCalculationSettings(
      method: method ?? PrayerCalculationSettings.fallback.method,
      school: school ?? PrayerCalculationSettings.fallback.school,
    );
  }

  /// Where the timezone said nothing: ask where the device actually is. An
  /// unknown answer (no location yet, geocoder offline) is retried on the
  /// next launch rather than saved.
  Future<void> _resolveFromLocation() async {
    final String? country;
    try {
      country = await ref.read(deviceCountryCodeProvider.future);
    } catch (_) {
      return; // unknown: tried again on the next launch
    }
    if (_disposed || country != 'PK') return;
    await _applyPakistanDefaults(updateState: true);
  }

  /// Saves Karachi / Hanafi for whichever of the two the user has not chosen.
  /// Re-reads storage first: a manual choice made meanwhile always wins.
  Future<void> _applyPakistanDefaults({required bool updateState}) async {
    if (_disposed) return;
    final storage = ref.read(localStorageServiceProvider);
    const defaults = PrayerCalculationSettings.pakistan;

    var next = state;
    if (storage.get<int>(AppConstants.settingsBoxName, _methodKey) == null) {
      await storage.put(
        AppConstants.settingsBoxName,
        _methodKey,
        defaults.method.id,
      );
      next = next.copyWith(method: defaults.method);
    }
    if (storage.get<int>(AppConstants.settingsBoxName, _schoolKey) == null) {
      await storage.put(
        AppConstants.settingsBoxName,
        _schoolKey,
        defaults.school.id,
      );
      next = next.copyWith(school: defaults.school);
    }
    if (updateState && !_disposed) state = next;
  }

  Future<void> setMethod(PrayerCalculationMethod method) async {
    state = state.copyWith(method: method);
    await ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, _methodKey, method.id);
  }

  Future<void> setSchool(AsrSchool school) async {
    state = state.copyWith(school: school);
    await ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, _schoolKey, school.id);
  }
}

final prayerCalculationSettingsProvider =
    NotifierProvider<
      PrayerCalculationSettingsNotifier,
      PrayerCalculationSettings
    >(PrayerCalculationSettingsNotifier.new);
