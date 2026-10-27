/// What the phone says about its network. This is a *hint*, not proof: it
/// reports interfaces, not whether data actually flows.
abstract class ConnectivitySource {
  /// Whether any network interface is up right now. Answers `true` when the
  /// platform can't say, so an unknown never reads as offline.
  Future<bool> hasInterface();

  /// Emits whenever the interface state may have changed.
  Stream<bool> get interfaceChanges;
}

/// Asks "can the app really get data through?" with one small request.
abstract class ReachabilityProbe {
  /// True if the backend answered at all, with any status.
  Future<bool> canReachBackend();
}
