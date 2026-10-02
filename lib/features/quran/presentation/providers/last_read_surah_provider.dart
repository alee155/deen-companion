import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/surah_summary.dart';
import 'quran_providers.dart';

/// The surah the user most recently played, if any — derived from real
/// recent-activity history rather than a separate "last read" concept the
/// app doesn't otherwise track. Resolves to null until both the activity
/// log and the surah list have loaded, and whenever there's no surah
/// activity yet.
final lastReadSurahProvider = Provider<SurahSummary?>((ref) {
  final recent =
      ref.watch(recentActivityNotifierProvider).valueOrNull ?? const [];
  final surahs = ref.watch(surahListNotifierProvider).valueOrNull ?? const [];
  if (surahs.isEmpty) return null;

  RecentActivityItem? lastSurahActivity;
  for (final item in recent) {
    if (item.type == RecentActivityType.surah) {
      lastSurahActivity = item;
      break;
    }
  }
  if (lastSurahActivity == null) return null;

  final number = int.tryParse(lastSurahActivity.referenceId);
  if (number == null) return null;

  for (final surah in surahs) {
    if (surah.number == number) return surah;
  }
  return null;
});
