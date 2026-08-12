import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Thin wrapper around `package_info_plus`, kept behind an interface for
/// the same reason `LocationService` is (`core/location/location_service.dart`):
/// call sites depend on this abstraction, not the plugin directly, so a
/// fake can be swapped in for tests without touching a platform channel.
///
/// Android is the only target right now, and nothing here is
/// Android-specific on purpose — `PackageInfo.fromPlatform()` reads
/// whatever the running platform actually reports (on Android: the
/// `versionName`/`versionCode` from `android/app/build.gradle.kts`, which
/// in this project are themselves sourced from the `version:` line in
/// `pubspec.yaml` — see `flutter.versionCode` / `flutter.versionName` in
/// that gradle file). If iOS is ever targeted, this same service already
/// reports the real values there too, with no changes needed.
abstract class AppInfoService {
  /// Version name for the running build, e.g. `"1.0.0"`.
  Future<String> getVersionName();

  /// Build number for the running build, e.g. `"1"` — the integer after
  /// the `+` in pubspec.yaml's `version: 1.0.0+1`.
  Future<String> getBuildNumber();

  /// Version name and build number combined, e.g. `"1.0.0 (1)"` — what a
  /// Settings/About screen's "Version" row actually wants to show.
  Future<String> getDisplayVersion();
}

class PackageInfoAppInfoService implements AppInfoService {
  PackageInfoAppInfoService();

  // The installed build's version info can't change while the app is
  // running — a real update always restarts the process — so the one
  // underlying platform-channel call is made at most once per app launch
  // and reused for every subsequent call, exactly like the memoized
  // Mobile Ads SDK init in AdsRepositoryImpl.
  Future<PackageInfo>? _cached;

  Future<PackageInfo> _load() {
    return _cached ??= PackageInfo.fromPlatform();
  }

  @override
  Future<String> getVersionName() async => (await _load()).version;

  @override
  Future<String> getBuildNumber() async => (await _load()).buildNumber;

  @override
  Future<String> getDisplayVersion() async {
    final info = await _load();
    return '${info.version} (${info.buildNumber})';
  }
}

final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  return PackageInfoAppInfoService();
});

/// Just the version name, e.g. `"1.0.0"` — for compact branding text like
/// the Profile screen's footer ("Deen · v1.0.0").
final appVersionNameProvider = FutureProvider<String>((ref) {
  return ref.watch(appInfoServiceProvider).getVersionName();
});

/// Version name + build number, e.g. `"1.0.0 (1)"` — for an explicit
/// "Version" row in Settings, where the build number is actually useful
/// (support requests, bug reports).
final appDisplayVersionProvider = FutureProvider<String>((ref) {
  return ref.watch(appInfoServiceProvider).getDisplayVersion();
});
