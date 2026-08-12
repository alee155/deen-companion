import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'core/di/providers.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/utils/logger.dart';
import 'features/ads/presentation/providers/ads_providers.dart';
import 'features/ads/presentation/providers/app_open_ad_manager.dart';
import 'features/prayer_reminders/presentation/providers/reminders_provider.dart';
import 'firebase_options.dart';

Future<void> bootstrap() async {
  final bootStart = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // THE ACTUAL WIN: MobileAds.instance.initialize() has no dependency on
  // Firebase or local storage, so there's no reason for it to wait behind
  // either. Firing it here, before storage.init()/Firebase.initializeApp(),
  // lets the ad network's own (slow — routinely 1-4s) round trip start
  // that much earlier. Not awaited: AdsRepositoryImpl._ensureInitialized()
  // calls MobileAdsInitializer.initialize() again later and — thanks to
  // the guard added there — just picks up this same in-flight/completed
  // call instead of double-firing it.
  final mobileAdsInitFuture = container
      .read(mobileAdsInitializerProvider)
      .initialize();
  debugPrint(
    '[Boot] MobileAds SDK init kicked off at '
    '+${DateTime.now().difference(bootStart).inMilliseconds}ms',
  );

  final storageService = container.read(localStorageServiceProvider);
  await storageService.init();
  debugPrint(
    '[Boot] storage.init() done at +${DateTime.now().difference(bootStart).inMilliseconds}ms',
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(
      '[Boot] Firebase.initializeApp() done at '
      '+${DateTime.now().difference(bootStart).inMilliseconds}ms',
    );
  } catch (error, stackTrace) {
    debugPrint('[Boot] Firebase.initializeApp() failed: $error');
    AppLogger.e('Firebase initialization failed', error, stackTrace);
  }

  container.read(themeModeNotifierProvider);

  FlutterError.onError = (details) {
    AppLogger.e('Flutter error', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Uncaught platform error', error, stack);
    return true;
  };

  debugPrint(
    '[Boot] calling runApp() at +${DateTime.now().difference(bootStart).inMilliseconds}ms',
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const DeenApp()),
  );

  // Ads first: this is the fire-and-forget call that matters most for
  // perceived App Open latency, so it gets first crack at the event loop
  // among everything below. It reuses mobileAdsInitFuture's work via the
  // guard in MobileAdsInitializer — nothing is requested twice.
  debugPrint('[Ads] bootstrap: starting AppOpenAdManager + ads SDK init');
  container.read(appOpenAdManagerProvider).start();
  unawaited(container.read(adsInitializationProvider.future));

  unawaited(_initAudioBackground(bootStart));
  _syncPrayerReminders(container);

  unawaited(mobileAdsInitFuture); // keep the reference alive/analyzed
}

Future<void> _syncPrayerReminders(ProviderContainer container) async {
  try {
    await container.read(prayerReminderServiceProvider).syncIfEnabled();
  } catch (error, stackTrace) {
    AppLogger.e('Prayer reminder startup sync failed', error, stackTrace);
  }
}

Future<void> _initAudioBackground(DateTime bootStart) async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.devsouq.deen_companion.app.audio',
      androidNotificationChannelName: 'Quran audio playback',
      androidNotificationOngoing: true,
    );
    debugPrint(
      '[Boot] audio background init done at '
      '+${DateTime.now().difference(bootStart).inMilliseconds}ms',
    );
  } catch (error, stackTrace) {
    // A failure here only costs background playback controls — it must
    // never stop the app from starting.
    AppLogger.e('Audio background init failed', error, stackTrace);
  }
}
