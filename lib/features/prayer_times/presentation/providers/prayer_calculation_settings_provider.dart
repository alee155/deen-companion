import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/flow_log.dart';
import '../../domain/entities/prayer_calculation_settings.dart';

/// A country code known without any permission or network — a Pakistani
/// device timezone (PKT) means Pakistan. Null when the timezone says
/// nothing. A provider so tests don't depend on the machine's timezone.
final quickCountryProvider = Provider<String?>(
  (ref) => DateTime.now().timeZoneName == 'PKT' ? 'PK' : null,
);

/// What the user (or their account) has actually decided, as opposed to the
/// default shown while nothing is decided. Null means "not decided".
class PrayerSettingsChoice {
  final int? methodId;
  final int? schoolId;

  /// The user changed method or school and the server has not been told yet.
  final bool changedByUser;

  const PrayerSettingsChoice({
    this.methodId,
    this.schoolId,
    this.changedByUser = false,
  });
}

/// Bumped each time the user picks a method or school, so prayer times
/// refetch (and tell the server) for that change and for nothing else.
final prayerSettingsRevisionProvider = StateProvider<int>((ref) => 0);

/// Method and Asr school.
///
/// The backend calculates the times, so these are only sent when they are
/// the user's own choice (see `MethodSendRule`). Until then the screen shows
/// the default the server will apply — Karachi + Hanafi in Pakistan or where
/// the country is unknown, Muslim World League + Shafi elsewhere — and once a
/// request succeeds the server's actual values are adopted, so a second phone
/// on the same account shows what the account saved instead of overwriting
/// it. Defaults are never saved: only a choice or an adoption is.
class PrayerCalculationSettingsNotifier
    extends Notifier<PrayerCalculationSettings> {
  static const _methodKey = 'prayer_calculation_method';
  static const _schoolKey = 'prayer_asr_school';
  static const _changedKey = 'prayer_settings_changed';
  static const _tag = 'SETTINGS';

  bool _disposed = false;

  @override
  PrayerCalculationSettings build() {
    ref.onDispose(() => _disposed = true);

    final choice = this.choice;
    final method = _methodFor(choice.methodId);
    final school = _schoolFor(choice.schoolId);

    PrayerCalculationSettings fallbackFor(String? country) =>
        _isOutsidePakistan(country)
        ? PrayerCalculationSettings.fallback
        : PrayerCalculationSettings.pakistan;

    if (method != null && school != null) {
      return PrayerCalculationSettings(method: method, school: school);
    }

    // The timezone answers instantly; the device location can follow.
    final quick = ref.read(quickCountryProvider);
    if (quick == null) Future.microtask(_refineDefaultFromLocation);
    final defaults = fallbackFor(quick);
    FlowLog.data(_tag, 'nothing decided yet, showing the default', {
      'country': quick ?? 'unknown',
      'method': defaults.method.label,
      'school': defaults.school.label,
    });
    return PrayerCalculationSettings(
      method: method ?? defaults.method,
      school: school ?? defaults.school,
    );
  }

  PrayerSettingsChoice get choice {
    final storage = ref.read(localStorageServiceProvider);
    int? id(String key) => storage.get<int>(AppConstants.settingsBoxName, key);
    return PrayerSettingsChoice(
      // Unknown or retired ids count as "not decided".
      methodId: _methodFor(id(_methodKey))?.id,
      schoolId: _schoolFor(id(_schoolKey))?.id,
      changedByUser:
          storage.get<bool>(AppConstants.settingsBoxName, _changedKey) ?? false,
    );
  }

  static bool _isOutsidePakistan(String? country) =>
      country != null && country.isNotEmpty && country.toUpperCase() != 'PK';

  /// Once the device country is known, fix up whichever setting is still an
  /// undecided default. Never touches a decision.
  Future<void> _refineDefaultFromLocation() async {
    final String? country;
    try {
      country = await ref.read(deviceCountryCodeProvider.future);
    } catch (_) {
      return; // unknown: the Pakistan/server default stays
    }
    if (_disposed || !_isOutsidePakistan(country)) return;

    final choice = this.choice;
    state = state.copyWith(
      method: choice.methodId == null
          ? PrayerCalculationSettings.fallback.method
          : null,
      school: choice.schoolId == null
          ? PrayerCalculationSettings.fallback.school
          : null,
    );
  }

  static PrayerCalculationMethod? _methodFor(int? id) {
    for (final m in PrayerCalculationMethod.values) {
      if (m.id == id) return m;
    }
    return null;
  }

  static AsrSchool? _schoolFor(int? id) {
    for (final s in AsrSchool.values) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The user picked a method. Remembered, and flagged so the server hears
  /// about it on the next refresh.
  Future<void> setMethod(PrayerCalculationMethod method) async {
    FlowLog.log(
      _tag,
      'USER PICKED METHOD: ${method.id} ${method.label} -> will be sent to the server',
    );
    state = state.copyWith(method: method);
    await _store(_methodKey, method.id, changed: true);
    ref.read(prayerSettingsRevisionProvider.notifier).state++;
  }

  Future<void> setSchool(AsrSchool school) async {
    FlowLog.log(
      _tag,
      'USER PICKED ASR SCHOOL: ${school.id} ${school.label} -> will be sent to the server',
    );
    state = state.copyWith(school: school);
    await _store(_schoolKey, school.id, changed: true);
    ref.read(prayerSettingsRevisionProvider.notifier).state++;
  }

  /// The server's values are the truth (the account's saved choice, or what
  /// it applied): show and remember them. Not a user change, so nothing is
  /// sent back.
  Future<void> adopt({required int methodId, required int schoolId}) async {
    final method = _methodFor(methodId);
    final school = _schoolFor(schoolId);
    if (method == null || school == null) {
      FlowLog.log(
        _tag,
        'SERVER SETTINGS IGNORED: unknown id $methodId/$schoolId',
      );
      return;
    }
    FlowLog.log(
      _tag,
      'ADOPTED SERVER SETTINGS: method ${method.id} ${method.label}, school ${school.label}',
    );
    if (!_disposed) {
      state = PrayerCalculationSettings(method: method, school: school);
    }
    final storage = ref.read(localStorageServiceProvider);
    await storage.put(AppConstants.settingsBoxName, _methodKey, methodId);
    await storage.put(AppConstants.settingsBoxName, _schoolKey, schoolId);
  }

  /// The server has the user's change.
  Future<void> markSynced() {
    FlowLog.log(_tag, 'USER CHANGE REACHED THE SERVER (no longer pending)');
    return ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, _changedKey, false);
  }

  Future<void> _store(String key, int id, {required bool changed}) async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.put(AppConstants.settingsBoxName, key, id);
    if (changed) {
      await storage.put(AppConstants.settingsBoxName, _changedKey, true);
    }
  }
}

final prayerCalculationSettingsProvider =
    NotifierProvider<
      PrayerCalculationSettingsNotifier,
      PrayerCalculationSettings
    >(PrayerCalculationSettingsNotifier.new);
