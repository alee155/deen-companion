import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;
  NetworkInfoImpl(this.connectivity);

  /// Deliberately optimistic. `checkConnectivity` is only a hint about the
  /// *interface* state — it lies on emulators, some VPN setups, and captive
  /// portals, and it can throw outright when the platform channel isn't
  /// ready yet. Treating an unknown answer as "offline" is what produced
  /// spurious "You're offline. Check your connection." screens on devices
  /// that were perfectly online, so anything other than an explicit
  /// none-only result counts as connected and the real request is allowed to
  /// run — a genuine failure then surfaces as a network error from Dio.
  @override
  Future<bool> get isConnected async {
    try {
      final result = await connectivity.checkConnectivity().timeout(
        const Duration(seconds: 3),
      );
      if (result.isEmpty) return true;
      return !(result.length == 1 && result.first == ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl(Connectivity());
});
