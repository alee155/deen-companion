import 'dart:async';

import 'package:deen_companion/core/connectivity/domain/connectivity_ports.dart';
import 'package:deen_companion/core/connectivity/presentation/providers/connectivity_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A phone whose network the test controls.
class FakeConnectivitySource implements ConnectivitySource {
  bool up;
  int reads = 0;
  final _changes = StreamController<bool>.broadcast();

  FakeConnectivitySource({this.up = true});

  @override
  Future<bool> hasInterface() async {
    reads++;
    return up;
  }

  @override
  Stream<bool> get interfaceChanges => _changes.stream;

  /// The phone's network changes, as the platform would report it.
  void set(bool value) {
    up = value;
    _changes.add(value);
  }

  void dispose() => _changes.close();
}

/// A backend that answers or doesn't, as the test decides.
class FakeProbe implements ReachabilityProbe {
  bool reachable;
  int calls = 0;
  Completer<bool>? hold;

  FakeProbe({this.reachable = true});

  @override
  Future<bool> canReachBackend() async {
    calls++;
    final pending = hold;
    if (pending != null) return pending.future;
    return reachable;
  }
}

ProviderContainer connectivityContainer(
  FakeConnectivitySource source,
  FakeProbe probe, {
  DateTime Function()? now,
}) {
  return ProviderContainer(
    overrides: [
      connectivitySourceProvider.overrideWithValue(source),
      reachabilityProbeProvider.overrideWithValue(probe),
      if (now != null) connectivityClockProvider.overrideWithValue(now),
    ],
  );
}
