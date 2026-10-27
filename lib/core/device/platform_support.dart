import 'package:flutter/foundation.dart';

/// Features that depend on something only one platform offers.
class PlatformSupport {
  PlatformSupport._();

  /// Prayer-time Do Not Disturb. Android lets an app change DND once the user
  /// grants Notification Policy access; iOS gives apps no way to change a
  /// Focus mode, so the feature is not offered there.
  static bool get prayerDnd => defaultTargetPlatform == TargetPlatform.android;

  /// The iOS stand-in for [prayerDnd]: a guide to scheduling a Focus, since an
  /// app can't switch one on itself.
  static bool get prayerSilenceGuide =>
      defaultTargetPlatform == TargetPlatform.iOS;
}
