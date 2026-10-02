import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../audio_player/domain/audio_track.dart';
import '../../../audio_player/presentation/providers/audio_player_provider.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/surah_summary.dart';

/// Starts playing [surah]'s recitation and logs it as recent activity.
/// Shared by every place a surah can be played from (the list's per-row
/// play button, the Last Read card's "Continue Reading" button) so the
/// AudioTrack/RecentActivityItem construction lives in exactly one place.
/// Navigation to the player screen is left to the caller.
void playSurah(WidgetRef ref, SurahSummary surah) {
  ref
      .read(audioPlayerNotifierProvider.notifier)
      .playTrack(
        AudioTrack(
          id: 'surah-${surah.number}',
          titleEnglish: surah.nameEnglish,
          titleArabic: surah.nameArabic,
          reciterName:
              'Mishary Rashid Alafasy', // meta's single reciter for now
          url: surah.exampleAudioUrl,
        ),
      );
  ref
      .read(recentActivityNotifierProvider.notifier)
      .logActivity(
        RecentActivityItem(
          id: RecentActivityItem.buildId(
            RecentActivityType.surah,
            '${surah.number}',
          ),
          type: RecentActivityType.surah,
          referenceId: '${surah.number}',
          title: surah.nameEnglish,
          subtitle: '${surah.nameTranslation} · ${surah.versesCount} verses',
          route: '/quran',
          viewedAt: DateTime.now(),
        ),
      );
}
