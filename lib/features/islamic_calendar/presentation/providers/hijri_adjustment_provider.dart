import 'dart:ui' show PlatformDispatcher;

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

  /// Fine-tune range, in days relative to the calculated (API) date. The
  /// calculated date follows the Saudi calendar; Pakistan's moon-sighting
  /// date usually runs one day behind it and, some months, two.
  static const minOffset = -2;
  static const maxOffset = 1;

  /// The usual Pakistan gap. It is a starting point, not a promise: the
  /// Ruet-e-Hilal announcement decides each month, so users can fine-tune.
  static const pakistanOffset = -1;

  @override
  int build() {
    final storage = ref.read(localStorageServiceProvider);
    final stored = storage.get<int>(AppConstants.settingsBoxName, _key);
    if (stored != null) return stored;

    // No preference yet: resolve a regional default in the background. It
    // only writes once it has a *definite* answer, so an unknown region
    // (location not granted yet, geocoder offline) is retried on later
    // launches instead of being saved as "Automatic" forever.
    _pickInitialDefault();
    return 0;
  }

  Future<void> _pickInitialDefault() async {
    final storage = ref.read(localStorageServiceProvider);

    // Cheapest definite signal first: a Pakistani device timezone (PKT).
    // Works with no permission and no network.
    var country = DateTime.now().timeZoneName == 'PKT' ? 'PK' : null;

    // Then where the device actually is.
    country ??= await ref.read(deviceCountryCodeProvider.future);

    // The device's own region setting, as a last hint.
    country ??= PlatformDispatcher.instance.locale.countryCode;

    // A manual choice made while this was resolving wins outright.
    if (storage.get<int>(AppConstants.settingsBoxName, _key) != null) return;

    if (country == null || country.isEmpty) return; // unknown — try again later
    if (country == 'PK') {
      await setPakistan();
    } else {
      await setAutomatic();
    }
  }

  Future<void> _set(int value) async {
    state = value;
    await ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, _key, value);
  }

  /// Show exactly what the API returns.
  Future<void> setAutomatic() => _set(0);

  /// The usual Pakistan offset (one day behind the calculated date).
  Future<void> setPakistan() => _set(pakistanOffset);

  /// Any whole-day offset within [minOffset]..[maxOffset].
  Future<void> setOffset(int days) => _set(days.clamp(minOffset, maxOffset));
}

final hijriAdjustmentProvider = NotifierProvider<HijriAdjustmentNotifier, int>(
  HijriAdjustmentNotifier.new,
);
