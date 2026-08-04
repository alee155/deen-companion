import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/location/location_service.dart';

/// Which Hijri date the app shows, in whole days relative to what the API
/// returns:
/// - Automatic (0): show exactly what the API returns.
/// - Pakistan (-1): always show one day earlier than the API's value —
///   this is the date actually observed in Pakistan (Ruet-e-Hilal
///   Committee), which regularly runs a day behind the calculated date.
///
/// This is a pure, explicit choice — once set, nothing here silently
/// overrides it, and the offset is exactly whichever of these two was
/// chosen, persisted, and applied immediately wherever it's used.
///
/// The one exception is the very first time the app ever needs this value
/// (no stored preference at all): rather than defaulting everyone to
/// Automatic and making Pakistan-based users manually discover and flip a
/// setting, a one-time country check picks Pakistan for them automatically
/// if that's where the device is. This runs at most once per install —
/// the moment it resolves, it calls the exact same setPakistan()/
/// setAutomatic() a manual tap would, which persists the choice and makes
/// it indistinguishable from one the user picked themselves. That's what
/// keeps this from regressing into the earlier bug class where "Automatic"
/// silently re-resolved on every launch and could fight with the button
/// the user had actually tapped.
class HijriAdjustmentNotifier extends Notifier<int> {
  static const _key = 'hijri_date_adjustment';

  @override
  int build() {
    final storage = ref.read(localStorageServiceProvider);
    final stored = storage.get<int>(AppConstants.settingsBoxName, _key);
    if (stored != null) return stored;

    // No preference exists yet at all — this is (as far as this device's
    // local storage is concerned) the first time the app has ever needed
    // this value. Kick off the one-time regional default in the
    // background; it writes its own persisted choice once it resolves,
    // so this only ever runs while stored == null, i.e. once per install.
    _pickInitialDefault();
    return 0; // Automatic, until/unless the one-time check says otherwise.
  }

  Future<void> _pickInitialDefault() async {
    final countryCode = await ref.read(deviceCountryCodeProvider.future);

    // If the user already tapped a choice manually while this was
    // resolving, that choice wins outright — don't overwrite it.
    final storage = ref.read(localStorageServiceProvider);
    if (storage.get<int>(AppConstants.settingsBoxName, _key) != null) return;

    if (countryCode == 'PK') {
      await setPakistan();
    } else {
      // Explicitly persisted, not left implicit — this ensures the
      // country check above never runs again on a future cold start,
      // exactly matching what a manual tap would have done.
      await setAutomatic();
    }
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
