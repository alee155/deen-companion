import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'core/di/providers.dart';
import 'core/utils/logger.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  final storageService = container.read(localStorageServiceProvider);
  await storageService.init();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.deen_companion.audio',
    androidNotificationChannelName: 'Quran audio playback',
    androidNotificationOngoing: true,
  );

  FlutterError.onError = (details) {
    AppLogger.e('Flutter error', details.exception, details.stack);
  };

  runApp(
    UncontrolledProviderScope(container: container, child: const DeenApp()),
  );
}
