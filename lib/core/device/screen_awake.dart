import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/logger.dart';

/// Keeps the screen on while something is being read. Several readers can be
/// open on top of each other, so the screen is only released when the last
/// one closes.
abstract final class ScreenAwake {
  static int _holders = 0;

  static void acquire() {
    if (_holders++ == 0) _set(true);
  }

  static void release() {
    if (_holders == 0) return;
    if (--_holders == 0) _set(false);
  }

  /// Never throws: a platform without the plugin (or a test) just skips it.
  static void _set(bool on) {
    final call = on ? WakelockPlus.enable() : WakelockPlus.disable();
    call.catchError((Object e, StackTrace st) {
      AppLogger.e('ScreenAwake: could not set the wakelock to $on', e, st);
    });
  }
}

/// Add to a reader screen's `State` to keep the screen awake while it is open.
mixin KeepScreenOnMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ScreenAwake.acquire();
  }

  @override
  void dispose() {
    ScreenAwake.release();
    super.dispose();
  }
}
