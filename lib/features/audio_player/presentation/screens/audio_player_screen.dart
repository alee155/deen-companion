import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../favorites/domain/entities/favorite_item.dart';
import '../providers/audio_player_provider.dart';
import '../providers/surah_navigation.dart';
import '../widgets/now_playing_view.dart';

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerNotifierProvider);
    final player = ref.read(audioPlayerNotifierProvider.notifier);
    final track = audioState.track;

    if (track == null) {
      // No self-navigation here: onStop/onMinimize are the only places that
      // pop. stop() clears the track (triggering this rebuild) before onStop's
      // own pop runs, so popping here too would overshoot by one screen.
      return const Scaffold(body: SizedBox.shrink());
    }

    final referenceId = track.id.replaceFirst('surah-', '');
    final favoriteItem = FavoriteItem(
      id: FavoriteItem.buildId(FavoriteContentType.surah, referenceId),
      type: FavoriteContentType.surah,
      referenceId: referenceId,
      title: track.titleEnglish,
      subtitle: track.reciterName,
      route: '/quran',
      savedAt: DateTime.now(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF16110D),
      body: NowPlayingView(
        titleArabic: track.titleArabic,
        titleEnglish: track.titleEnglish,
        reciterName: track.reciterName,
        surahNumber: int.tryParse(referenceId),
        favoriteItem: favoriteItem,
        isPlaying: audioState.isPlaying,
        isLooping: audioState.isLooping,
        speed: audioState.speed,
        position: audioState.position,
        duration: audioState.duration,
        sleepTimerRemaining: audioState.sleepTimerRemaining,
        onPlayPause: player.togglePlayPause,
        onNext: () => playAdjacentSurah(ref, delta: 1),
        onPrevious: () => playAdjacentSurah(ref, delta: -1),
        onBack10: player.skipBackward,
        onForward10: player.skipForward,
        onSeek: player.seek,
        onToggleLoop: player.toggleLoop,
        onSetSpeed: player.setSpeed,
        onSetSleepTimer: player.setSleepTimer,
        onCancelSleepTimer: player.cancelSleepTimer,
        onStop: () {
          context.pop();
          player.stop();
        },
        onMinimize: () => context.pop(),
      ),
    );
  }
}
