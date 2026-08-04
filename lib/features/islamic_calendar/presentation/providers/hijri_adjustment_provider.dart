import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';

/// Which Hijri date the app shows, in whole days relative to what the API
/// returns:
/// - Automatic (0): show exactly what the API returns, always. No location,
///   no detection, no adjustment of any kind.
/// - Pakistan (-1): always show one day earlier than the API's value —
///   this is the date actually observed in Pakistan (Ruet-e-Hilal
///   Committee), which regularly runs a day behind the calculated date.
///
/// This is a pure, explicit user choice. Nothing here reads location or
/// guesses a default — the offset is exactly whichever of these two the
/// user picked, persisted, and applied immediately wherever it's used.
class HijriAdjustmentNotifier extends Notifier<int> {
  static const _key = 'hijri_date_adjustment';

  @override
  int build() {
    final storage = ref.read(localStorageServiceProvider);
    return storage.get<int>(AppConstants.settingsBoxName, _key) ?? 0;
  }

  /// Show exactly what the API returns.
  Future<void> setAutomatic() async {
    state = 0;
    await ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, _key, 0);
  }

  /// Always show one day earlier than the API's value, matching Pakistan's
  /// observed date.
  Future<void> setPakistan() async {
    state = -1;
    await ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, _key, -1);
  }
}

final hijriAdjustmentProvider = NotifierProvider<HijriAdjustmentNotifier, int>(
  HijriAdjustmentNotifier.new,
);
