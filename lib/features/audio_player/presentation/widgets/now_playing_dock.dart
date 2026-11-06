import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../providers/audio_player_provider.dart';
import '../providers/surah_navigation.dart';
import 'mini_player_bar.dart';

/// The mini player, wired to the audio state: nothing while no track is
/// loaded, otherwise the capsule with play/pause, next and close.
///
/// The tab shell docks it above the navigation bar; screens pushed on top of
/// the shell (Quran, Juz…) use it as their `bottomNavigationBar` so a playing
/// surah stays visible and controllable while the user reads.
class NowPlayingDock extends ConsumerWidget {
  const NowPlayingDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioPlayerNotifierProvider);

    return AnimatedSize(
      duration: context.motion.duration(AppMotion.normal),
      curve: AppMotion.emphasized,
      alignment: Alignment.bottomCenter,
      child: ContentSwitcher(
        alignment: Alignment.bottomCenter,
        child: !audio.hasTrack
            ? const SizedBox(key: ValueKey('no-mini'), width: double.infinity)
            : MiniPlayerBar(
                key: const ValueKey('mini'),
                title: audio.track!.titleEnglish,
                titleArabic: audio.track!.titleArabic,
                subtitle: audio.track!.reciterName,
                isPlaying: audio.isPlaying,
                progress: audio.duration.inMilliseconds == 0
                    ? 0.0
                    : audio.position.inMilliseconds /
                          audio.duration.inMilliseconds,
                onTap: () => context.push('/player'),
                onPlayPause: () => ref
                    .read(audioPlayerNotifierProvider.notifier)
                    .togglePlayPause(),
                onNext: () => playAdjacentSurah(ref, delta: 1),
                onClose: () =>
                    ref.read(audioPlayerNotifierProvider.notifier).stop(),
              ),
      ),
    );
  }
}
