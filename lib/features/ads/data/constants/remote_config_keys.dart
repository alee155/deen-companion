/// Firebase Remote Config parameter names, exactly as configured in the
/// Firebase console for this project. Centralized here so a typo in a key
/// name is a one-file fix, not a hunt through every call site — this is
/// the "centralized and reusable" piece the ad-unit resolution logic
/// depends on.
///
/// Each is a Boolean parameter:
///   `true`  → serve the real production AdMob ad unit for that format.
///   `false` → fall back to test ads in debug builds, or disable that ad
///             format entirely in release builds. See `AdUnitResolver`
///             for exactly how that decision is made.
class RemoteConfigKeys {
  RemoteConfigKeys._();

  static const String banner = 'Banner';
  static const String interstitial = 'Interstitial';
  static const String appOpen = 'AppOpen';
}
