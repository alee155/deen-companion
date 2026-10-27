import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/logger.dart';
import '../../data/connectivity_plus_source.dart';
import '../../data/http_reachability_probe.dart';
import '../../domain/connectivity_ports.dart';
import '../../domain/connectivity_state.dart';

final connectivitySourceProvider = Provider<ConnectivitySource>(
  (ref) => ConnectivityPlusSource(Connectivity()),
);

final reachabilityProbeProvider = Provider<ReachabilityProbe>(
  (ref) => HttpReachabilityProbe(),
);

/// The time source for the failure window. A provider so tests can run time
/// under their own control; the app uses the real clock.
final connectivityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Bumped each time the connection comes back after being offline. Features
/// listen to it to refresh what failed while the phone was offline, the same
/// way `unauthorizedEventProvider` signals a rejected sign-in.
final connectionRestoredProvider = StateProvider<int>((ref) => 0);

/// The app's single view of its internet connection.
///
/// Two kinds of input, weighed differently:
///
///  * **The phone's hint** (interface up or down). Trusted for "down", after a
///    short delay: Android briefly reports none while it hands over between
///    Wi-Fi and mobile data, and that must not flash an offline banner.
///  * **Real requests** (via `ConnectivityInterceptor`). A response proves the
///    connection works and ends any offline state at once. Repeated network
///    failures only *prompt a check*: one probe to our own backend decides.
///
/// It also re-checks whenever the app returns to the foreground, because iOS
/// and Android don't reliably deliver connectivity changes to a suspended app.
///
/// "Online" is the starting point and the default for anything unknown.
class ConnectivityNotifier extends Notifier<ConnectivityState>
    with WidgetsBindingObserver {
  /// How long the phone must keep reporting no network before the app says
  /// so. Long enough to ride out a Wi-Fi/mobile handover.
  static const offlineDelay = Duration(milliseconds: 1500);

  /// Network failures within [failureWindow] that make the app check.
  static const failureThreshold = 2;
  static const failureWindow = Duration(seconds: 20);

  Timer? _offlineTimer;
  StreamSubscription<bool>? _subscription;
  bool _interfaceUp = true;
  bool _alive = true;
  bool _probing = false;
  int _failures = 0;
  DateTime? _firstFailureAt;

  ConnectivitySource get _source => ref.read(connectivitySourceProvider);
  ReachabilityProbe get _probe => ref.read(reachabilityProbeProvider);

  @override
  ConnectivityState build() {
    _alive = true;
    _subscription = _source.interfaceChanges.listen(
      _onInterface,
      onError: (Object error, StackTrace stack) =>
          AppLogger.e('Connectivity stream failed', error, stack),
    );
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _alive = false;
      _offlineTimer?.cancel();
      _subscription?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    unawaited(_readInterface());
    return const ConnectivityState.online();
  }

  // ── Inputs ─────────────────────────────────────────────────────────────

  /// A real request got an answer: the connection works.
  void reportReachable() {
    if (!_alive) return;
    _failures = 0;
    _firstFailureAt = null;
    if (state.isOffline) _goOnline();
  }

  /// A real request could not connect or timed out. One is noise; a second
  /// within [failureWindow] earns a check.
  void reportUnreachable() {
    if (!_alive || state.isOffline) return;
    final now = ref.read(connectivityClockProvider)();
    final first = _firstFailureAt;
    if (first == null || now.difference(first) > failureWindow) {
      _firstFailureAt = now;
      _failures = 0;
    }
    if (++_failures >= failureThreshold) unawaited(_confirmUnreachable());
  }

  /// The user asked to check again (tapping the banner).
  Future<void> recheck() async {
    if (!_alive || _probing) return;
    state = state.copyWith(isChecking: true);
    final up = await _source.hasInterface();
    if (!_alive) return;
    _interfaceUp = up;
    if (!up) {
      _setOffline(OfflineReason.noInterface);
      return;
    }
    await _probeAndSettle();
  }

  @override
  // (Named `lifecycle`: `state` would hide this notifier's own state.)
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) unawaited(_readInterface());
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<void> _readInterface() async {
    final up = await _source.hasInterface();
    if (_alive) _onInterface(up);
  }

  void _onInterface(bool up) {
    if (!_alive) return;
    _interfaceUp = up;
    if (up) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      // Coming back from offline: confirm data really flows before saying so
      // (the network might be a captive portal).
      if (state.isOffline) unawaited(_confirmRestored());
      return;
    }
    if (state.isOffline) {
      // Already offline for another reason; the phone now agrees.
      _setOffline(OfflineReason.noInterface);
      return;
    }
    _offlineTimer ??= Timer(offlineDelay, () {
      _offlineTimer = null;
      if (_alive && !_interfaceUp) _setOffline(OfflineReason.noInterface);
    });
  }

  Future<void> _confirmRestored() async {
    state = state.copyWith(isChecking: true);
    await _probeAndSettle();
  }

  Future<void> _confirmUnreachable() async {
    if (_probing || !_interfaceUp) return;
    _failures = 0;
    _firstFailureAt = null;
    _probing = true;
    final reachable = await _probe.canReachBackend();
    _probing = false;
    if (!_alive) return;
    if (!reachable && state.isOnline) _setOffline(OfflineReason.unreachable);
  }

  Future<void> _probeAndSettle() async {
    _probing = true;
    final reachable = await _probe.canReachBackend();
    _probing = false;
    if (!_alive) return;
    if (reachable) {
      _goOnline();
    } else {
      _setOffline(OfflineReason.unreachable);
    }
  }

  void _setOffline(OfflineReason reason) {
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _failures = 0;
    _firstFailureAt = null;
    state = ConnectivityState.offline(reason);
  }

  void _goOnline() {
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _failures = 0;
    _firstFailureAt = null;
    final wasOffline = state.isOffline;
    state = const ConnectivityState.online();
    if (wasOffline) ref.read(connectionRestoredProvider.notifier).state++;
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(
      ConnectivityNotifier.new,
    );

/// Just "is the app online", for widgets and providers that don't care why.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider.select((s) => s.isOnline)),
);
