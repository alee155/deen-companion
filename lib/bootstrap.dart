import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'core/di/providers.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/utils/logger.dart';
import 'features/ads/presentation/providers/ads_providers.dart';
import 'features/ads/presentation/providers/app_open_ad_manager.dart';
import 'features/prayer_reminders/presentation/providers/reminders_provider.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  final storageService = container.read(localStorageServiceProvider);
  await storageService.init();

  // Storage is open by this point, so the persisted theme choice can be
  // restored before the first frame — the app opens in the user's chosen
  // brightness instead of flashing Light and then switching.
  container.read(themeModeNotifierProvider);

  // just_audio_background must be initialised *before* any AudioPlayer is
  // constructed, otherwise the media notification/background service never
  // attaches — and on release builds that surfaces as a foreground-service
  // exception the first time playback starts.
  await _initAudioBackground();

  FlutterError.onError = (details) {
    AppLogger.e('Flutter error', details.exception, details.stack);
  };

  // Errors raised outside the Flutter framework (platform channels, async
  // gaps) would otherwise be fatal in a release build.
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Uncaught platform error', error, stack);
    return true;
  };

  runApp(
    UncontrolledProviderScope(container: container, child: const DeenApp()),
  );

  // Opportunistic re-arm of the prayer alarm window on every cold start. The
  // native side keeps whatever is already scheduled alive across reboots, but
  // only Dart can fetch fresh timings — so this extends the window while the
  // app happens to be open. Deliberately not awaited: it must never delay the
  // first frame.
  _syncPrayerReminders(container);

  // Ads init (SDK setup + first interstitial/app-open preload) and the app
  // open lifecycle observer both start after the first frame, for the same
  // reason: nothing about monetization may ever delay the app becoming
  // interactive. `start()` on the manager begins observing immediately so
  // even a very fast background/foreground cycle right after launch is
  // caught correctly.
  //
  // Note: these two calls used to race against MobileAds.instance.initialize()
  // — AppOpenAdManager.start() and adsInitializationProvider both fired ad
  // requests independently, with no guarantee the SDK had finished
  // initializing first. That's now handled inside AdsRepositoryImpl itself
  // (every load path awaits an internal init-completer), so the order these
  // two lines run in no longer matters for correctness — left in this order
  // because it reads naturally, not because it's required.
  debugPrint('[Ads] bootstrap: starting AppOpenAdManager + ads SDK init');
  container.read(appOpenAdManagerProvider).start();
  unawaited(container.read(adsInitializationProvider.future));
}

Future<void> _syncPrayerReminders(ProviderContainer container) async {
  try {
    await container.read(prayerReminderServiceProvider).syncIfEnabled();
  } catch (error, stackTrace) {
    AppLogger.e('Prayer reminder startup sync failed', error, stackTrace);
  }
}

Future<void> _initAudioBackground() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.devsouq.deen_companion.app.audio',
      androidNotificationChannelName: 'Quran audio playback',
      androidNotificationOngoing: true,
    );
  } catch (error, stackTrace) {
    // A failure here only costs background playback controls — it must
    // never stop the app from starting.
    AppLogger.e('Audio background init failed', error, stackTrace);
  }
}
