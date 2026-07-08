import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/full_audio_player_sheet.dart';

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerNotifierProvider);
    final track = audioState.track;

    if (track == null) {
      // Nothing playing (e.g. deep link or stale route) — bail out safely.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).maybePop(),
      );
      return const Scaffold(body: SizedBox.shrink());
    }

    final progress = audioState.duration.inMilliseconds == 0
        ? 0.0
        : audioState.position.inMilliseconds /
              audioState.duration.inMilliseconds;

    return Scaffold(
      body: FullAudioPlayerSheet(
        surahNameArabic: track.titleArabic,
        surahNameEnglish: track.titleEnglish,
        reciterName: track.reciterName,
        currentAyah:
            1, // wired to real ayah tracking once verse-level playback lands
        totalAyahs: 1,
        isPlaying: audioState.isPlaying,
        progress: progress,
        elapsedLabel: _formatDuration(audioState.position),
        durationLabel: _formatDuration(audioState.duration),
        onPlayPause: () =>
            ref.read(audioPlayerNotifierProvider.notifier).togglePlayPause(),
        onSkipNext: () =>
            ref.read(audioPlayerNotifierProvider.notifier).skipForward(),
        onSkipPrevious: () =>
            ref.read(audioPlayerNotifierProvider.notifier).skipBackward(),
        onSleepTimer: () {}, // next iteration
        onRepeat: () {}, // next iteration
        onClose: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
