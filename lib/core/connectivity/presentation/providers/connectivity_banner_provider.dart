import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/connectivity_state.dart';
import 'connectivity_providers.dart';

enum BannerKind {
  hidden,
  offline,

  /// "Back online", shown briefly after an offline spell.
  restored,
}

class ConnectivityBannerState {
  final BannerKind kind;
  final OfflineReason? reason;
  final bool isChecking;

  const ConnectivityBannerState(
    this.kind, {
    this.reason,
    this.isChecking = false,
  });

  bool get isVisible => kind != BannerKind.hidden;

  @override
  bool operator ==(Object other) =>
      other is ConnectivityBannerState &&
      other.kind == kind &&
      other.reason == reason &&
      other.isChecking == isChecking;

  @override
  int get hashCode => Object.hash(kind, reason, isChecking);
}

/// What the banner shows, derived from the connection: the offline notice
/// while offline, then a short "Back online", then nothing.
///
/// Kept apart from [ConnectivityNotifier] because showing a message is a
/// presentation choice (how long "Back online" stays up), not part of what
/// the app knows about its connection.
class ConnectivityBannerNotifier extends Notifier<ConnectivityBannerState> {
  static const restoredFor = Duration(milliseconds: 2500);

  Timer? _hideTimer;

  @override
  ConnectivityBannerState build() {
    ref.listen(connectivityProvider, (previous, next) {
      _hideTimer?.cancel();
      if (next.isOffline) {
        state = ConnectivityBannerState(
          BannerKind.offline,
          reason: next.reason,
          isChecking: next.isChecking,
        );
      } else if (state.kind == BannerKind.offline) {
        state = const ConnectivityBannerState(BannerKind.restored);
        _hideTimer = Timer(restoredFor, () {
          state = const ConnectivityBannerState(BannerKind.hidden);
        });
      }
    });
    ref.onDispose(() => _hideTimer?.cancel());

    final now = ref.read(connectivityProvider);
    return now.isOffline
        ? ConnectivityBannerState(
            BannerKind.offline,
            reason: now.reason,
            isChecking: now.isChecking,
          )
        : const ConnectivityBannerState(BannerKind.hidden);
  }
}

final connectivityBannerProvider =
    NotifierProvider<ConnectivityBannerNotifier, ConnectivityBannerState>(
      ConnectivityBannerNotifier.new,
    );
