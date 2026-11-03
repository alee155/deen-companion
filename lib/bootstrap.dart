import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'core/di/providers.dart';
import 'core/storage/fresh_install_guard.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/utils/logger.dart';
import 'features/ads/presentation/providers/ads_providers.dart';
import 'features/ads/presentation/providers/app_open_ad_manager.dart';
import 'features/daily_content/presentation/providers/daily_notification_service.dart';
import 'features/prayer_dnd/presentation/providers/prayer_dnd_provider.dart';
import 'features/prayer_reminders/presentation/providers/prayer_alarm_launch_service.dart';
import 'features/prayer_reminders/presentation/providers/reminders_provider.dart';

Future<void> bootstrap() async {
  final bootStart = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  final storageService = container.read(localStorageServiceProvider);
  await storageService.init();
  debugPrint(
    '[Boot] storage.init() done at +${DateTime.now().difference(bootStart).inMilliseconds}ms',
  );

  await FreshInstallGuard(
    storage: storageService,
    tokens: container.read(tokenStorageProvider),
  ).run();

  container.read(themeModeNotifierProvider);

  // Many Android phones keep apps at 60 Hz by default. Ask for the best mode
  // the screen has; on a 60 Hz-only phone (or an Android too old to report
  // modes) this changes nothing.
  if (Platform.isAndroid) unawaited(_useHighRefreshRate());

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

  // Ads first, so the App Open ad has the whole splash animation to load.
  // Order inside the repository: ads config (saved copy or fetch) → consent
  // → SDK → ad request. Nothing here blocks the first frame.
  container.read(appOpenAdManagerProvider).start();
  unawaited(container.read(adsInitializationProvider.future));

  unawaited(_initAudioBackground(bootStart));
  _syncPrayerReminders(container);
  _syncPrayerDnd(container);
  container.read(dailyNotificationServiceProvider).start();
  container.read(prayerAlarmLaunchServiceProvider).start();
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

Future<void> _syncPrayerDnd(ProviderContainer container) async {
  try {
    await container.read(prayerDndServiceProvider).syncIfEnabled();
  } catch (error, stackTrace) {
    AppLogger.e('Prayer DND startup sync failed', error, stackTrace);
  }
}

Future<void> _useHighRefreshRate() async {
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e, st) {
    AppLogger.e('Boot: could not switch to a higher refresh rate', e, st);
  }
}
