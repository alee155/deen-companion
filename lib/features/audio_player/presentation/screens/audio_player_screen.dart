import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../quran/presentation/providers/quran_providers.dart';
import '../../domain/audio_track.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/full_audio_player_sheet.dart';

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerNotifierProvider);
    final track = audioState.track;

    if (track == null) {
      // No self-navigation here — onBack/onMinimize are the only places
      // that pop. This used to also pop itself, but stop() clears the
      // track (triggering this exact rebuild) *before* onBack's own pop
      // runs, so both fired almost together and overshot by one screen.
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
        isPlaying: audioState.isPlaying,
        isLooping: audioState.isLooping,
        progress: progress,
        duration: audioState.duration,
        elapsedLabel: _formatDuration(audioState.position),
        durationLabel: _formatDuration(audioState.duration),
        sleepTimerRemaining: audioState.sleepTimerRemaining,
        onPlayPause: () =>
            ref.read(audioPlayerNotifierProvider.notifier).togglePlayPause(),
        onSkipNext: () => _switchSurahReal(ref, track, delta: 1),
        onSkipPrevious: () => _switchSurahReal(ref, track, delta: -1),
        onToggleLoop: () =>
            ref.read(audioPlayerNotifierProvider.notifier).toggleLoop(),
        // onPickReciter: () => _showReciterPicker(context, ref),
        onSeek: (position) =>
            ref.read(audioPlayerNotifierProvider.notifier).seek(position),
        onSetSleepTimer: (duration) => ref
            .read(audioPlayerNotifierProvider.notifier)
            .setSleepTimer(duration),
        onCancelSleepTimer: () =>
            ref.read(audioPlayerNotifierProvider.notifier).cancelSleepTimer(),
        onBack: () {
          context.pop();
          ref.read(audioPlayerNotifierProvider.notifier).stop();
        },
        onMinimize: () => context.pop(),
      ),
    );
  }

  void _switchSurahReal(WidgetRef ref, AudioTrack track, {required int delta}) {
    final surahs = ref.read(surahListNotifierProvider).value;
    if (surahs == null) return;
    final currentNumber = int.tryParse(track.id.replaceFirst('surah-', ''));
    if (currentNumber == null) return;
    final targetIndex =
        surahs.indexWhere((s) => s.number == currentNumber) + delta;
    if (targetIndex < 0 || targetIndex >= surahs.length) return;

    final target = surahs[targetIndex];
    ref
        .read(audioPlayerNotifierProvider.notifier)
        .playTrack(
          AudioTrack(
            id: 'surah-${target.number}',
            titleEnglish: target.nameEnglish,
            titleArabic: target.nameArabic,
            // Reciter switching isn't wired up yet (see _showReciterPicker),
            // so we carry the currently-playing reciter forward.
            reciterName: track.reciterName,
            url: target.exampleAudioUrl,
          ),
        );
  }
}
