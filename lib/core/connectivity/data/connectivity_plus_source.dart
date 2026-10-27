import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/connectivity_ports.dart';

/// [ConnectivitySource] on top of `connectivity_plus`: `NWPathMonitor` on iOS,
/// `ConnectivityManager` on Android.
///
/// The plugin reports a *list* (Android reports Wi-Fi and VPN together, for
/// example). The phone has no interface only when the list is empty or holds
/// just `none`. Anything else counts as connected, the same optimistic rule
/// `NetworkInfoImpl` follows.
class ConnectivityPlusSource implements ConnectivitySource {
  final Connectivity _connectivity;
  ConnectivityPlusSource(this._connectivity);

  static const _readTimeout = Duration(seconds: 3);

  /// Exposed for tests: what a plugin result means.
  static bool interfaceUp(List<ConnectivityResult> results) =>
      results.isEmpty ||
      !(results.length == 1 && results.first == ConnectivityResult.none);

  @override
  Future<bool> hasInterface() async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(
        _readTimeout,
      );
      return interfaceUp(results);
    } catch (_) {
      // The platform channel isn't ready yet, or the call timed out.
      return true;
    }
  }

  @override
  Stream<bool> get interfaceChanges =>
      _connectivity.onConnectivityChanged.map(interfaceUp);
}
