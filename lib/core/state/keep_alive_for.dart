import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps an auto-dispose provider's data for [ttl] after the last screen using
/// it goes away, instead of throwing it away at once.
///
/// Without this, leaving a screen and coming back starts from nothing, so the
/// user sees a loading skeleton for data the app loaded seconds ago. With it,
/// the screen opens straight onto what was there and can refresh quietly.
///
/// The clock starts when the last listener leaves and is cancelled if someone
/// listens again. The returned link lets the caller drop the data early (for
/// example when the signed-in account changes, so one user's data is never
/// shown to the next).
KeepAliveLink keepAliveFor(AutoDisposeRef<Object?> ref, Duration ttl) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() {
    timer?.cancel();
    timer = Timer(ttl, link.close);
  });
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
  return link;
}
