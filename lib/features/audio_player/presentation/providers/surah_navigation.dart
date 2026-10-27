import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/presentation/providers/quran_providers.dart';
import '../../domain/audio_track.dart';
import 'audio_player_provider.dart';

/// Moves playback to the surah [delta] places away from the current one
/// (1 = next, -1 = previous). Does nothing at either end of the list, or while
/// the surah list hasn't loaded. Shared by the full player and the mini bar.
void playAdjacentSurah(WidgetRef ref, {required int delta}) {
  final track = ref.read(audioPlayerNotifierProvider).track;
  final surahs = ref.read(surahListNotifierProvider).value;
  if (track == null || surahs == null) return;

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
          // One reciter for now, so it carries over.
          reciterName: track.reciterName,
          url: target.exampleAudioUrl,
        ),
      );
}
