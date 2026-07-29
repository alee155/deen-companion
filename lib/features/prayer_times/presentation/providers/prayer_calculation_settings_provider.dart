import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/prayer_calculation_settings.dart';

class PrayerCalculationSettingsNotifier
    extends Notifier<PrayerCalculationSettings> {
  static const _methodKey = 'prayer_calculation_method';
  static const _schoolKey = 'prayer_asr_school';

  @override
  PrayerCalculationSettings build() {
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

    return PrayerCalculationSettings(
      method: method ?? PrayerCalculationSettings.fallback.method,
      school: school ?? PrayerCalculationSettings.fallback.school,
    );
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
