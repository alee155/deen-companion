import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Outcome of asking for ad consent.
class AdsConsentResult {
  /// False when the user's choices (or the region's rules) forbid ads.
  final bool canRequestAds;

  /// A consent form or the iOS tracking prompt was put in front of the user.
  /// The App Open ad skips that launch so two things never stack.
  final bool dialogShown;

  const AdsConsentResult({
    required this.canRequestAds,
    this.dialogShown = false,
  });
}

/// Everything that must be settled before the first ad request.
abstract class AdsConsent {
  Future<AdsConsentResult> gather();
}

/// Google's User Messaging Platform form (EU, UK, Switzerland), then Apple's
/// App Tracking Transparency prompt on iPhone.
///
/// UMP first: when an "IDFA explainer" message is set up in AdMob it shows the
/// tracking prompt itself, and the check below then finds nothing left to ask.
class PlatformAdsConsent implements AdsConsent {
  const PlatformAdsConsent();

  static const _infoTimeout = Duration(seconds: 5);

  @override
  Future<AdsConsentResult> gather() async {
    var shown = false;
    try {
      shown = await _gatherUmp();
    } catch (error) {
      debugPrint('[Ads] consent (UMP) failed: $error');
    }
    try {
      if (await _askTracking()) shown = true;
    } catch (error) {
      debugPrint('[Ads] tracking prompt failed: $error');
    }
    final canRequest = await _canRequestAds();
    return AdsConsentResult(canRequestAds: canRequest, dialogShown: shown);
  }

  Future<bool> _canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      // Consent state unreadable: no ads this session rather than a guess.
      return false;
    }
  }

  /// True when a form was shown.
  Future<bool> _gatherUmp() async {
    final info = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => info.complete(true),
      (error) {
        debugPrint('[Ads] consent info update failed: ${error.message}');
        if (!info.isCompleted) info.complete(false);
      },
    );
    final ok = await info.future.timeout(_infoTimeout, onTimeout: () => false);
    if (!ok) return false;

    final before = await ConsentInformation.instance.getConsentStatus();
    final formDone = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) {
        debugPrint('[Ads] consent form error: ${error.message}');
      }
      if (!formDone.isCompleted) formDone.complete();
    });
    await formDone.future;
    final after = await ConsentInformation.instance.getConsentStatus();
    return before == ConsentStatus.required && after != before;
  }

  Future<bool> _askTracking() async {
    if (!Platform.isIOS) return false;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return false;
    // iOS ignores the request unless the app is fully active.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await AppTrackingTransparency.requestTrackingAuthorization();
    return true;
  }
}
