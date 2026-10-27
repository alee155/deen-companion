import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/logger.dart';
import '../../data/prayer_alarm_channel.dart';
import '../../domain/prayer_alarm_launch.dart';

/// Opens the prayer screen when the user taps "Open" on a ringing iOS alarm.
///
/// The system alarm screen can't be restyled, so its Open button hands the
/// alarm to the app, which asks for it on launch and on every return to the
/// foreground. Same shape as the daily-notification tap handling: an alarm
/// that arrives before the router can take a push (cold start) waits for
/// [onHomeReady].
class PrayerAlarmLaunchService with WidgetsBindingObserver {
  final Ref ref;
  PrayerAlarmLaunchService(this.ref);

  bool _started = false;
  bool _routerReady = false;
  PrayerAlarmLaunch? _pending;

  /// Call once at launch. Only iOS has an alarm screen to come back from.
  void start() {
    if (_started || defaultTargetPlatform != TargetPlatform.iOS) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(check());
  }

  /// Home mounted: the router can take pushes, deliver what was waiting.
  Future<void> onHomeReady() async {
    _routerReady = true;
    await check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  Future<void> check() async {
    try {
      final launch =
          _pending ??
          await ref.read(prayerAlarmChannelProvider).consumeAlarmOpen();
      if (launch == null) return;
      if (!_routerReady) {
        _pending = launch;
        return;
      }
      _pending = null;
      ref.read(appRouterProvider).push('/prayer-alarm', extra: launch);
    } catch (error, stackTrace) {
      AppLogger.e('Opening the prayer screen failed', error, stackTrace);
    }
  }
}

final prayerAlarmLaunchServiceProvider = Provider<PrayerAlarmLaunchService>(
  (ref) => PrayerAlarmLaunchService(ref),
);
