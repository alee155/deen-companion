import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/presentation/providers/quran_providers.dart';
import '../../domain/audio_track.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/full_audio_player_sheet.dart';

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showReciterPicker(BuildContext context, WidgetRef ref) {
    final meta = ref.read(quranMetaNotifierProvider).value;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (meta == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Reciter list unavailable offline.'),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Choose reciter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkText,
                  ),
                ),
              ),
              ...meta.reciters.map(
                (r) => ListTile(
                  title: Text(r.name),
                  subtitle: Text(r.style),
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Switching reciters needs Surah Detail integration — coming soon.',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerNotifierProvider);
    final track = audioState.track;

    if (track == null) {
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
        currentAyah: 1,
        totalAyahs: 1,
        isPlaying: audioState.isPlaying,
        isLooping: audioState.isLooping,
        progress: progress,
        elapsedLabel: _formatDuration(audioState.position),
        durationLabel: _formatDuration(audioState.duration),
        onPlayPause: () =>
            ref.read(audioPlayerNotifierProvider.notifier).togglePlayPause(),
        onSkipNext: () => _switchSurahReal(ref, track, delta: 1),
        onSkipPrevious: () => _switchSurahReal(ref, track, delta: -1),
        onToggleLoop: () =>
            ref.read(audioPlayerNotifierProvider.notifier).toggleLoop(),
        onPickReciter: () => _showReciterPicker(context, ref),
        onClose: () => Navigator.of(context).maybePop(),
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
