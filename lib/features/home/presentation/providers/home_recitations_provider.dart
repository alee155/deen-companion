import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../quran/domain/entities/surah_summary.dart';
import '../../../quran/presentation/providers/quran_providers.dart';

/// Surah numbers featured on Home's recitations row — a fixed, curated set
/// rather than "first N in the list", so the row stays useful regardless of
/// list ordering.
const List<int> featuredSurahNumbers = [1, 2, 36, 55, 67];

/// The featured surahs, in [featuredSurahNumbers] order, derived from the
/// same real Surah list the Quran tab uses — never a separate data source,
/// so titles/verse counts/audio URLs can't drift from the rest of the app.
final featuredRecitationsProvider = Provider<AsyncValue<List<SurahSummary>>>((
  ref,
) {
  final surahsAsync = ref.watch(surahListNotifierProvider);
  return surahsAsync.whenData((surahs) {
    final byNumber = {for (final s in surahs) s.number: s};
    return featuredSurahNumbers
        .map((number) => byNumber[number])
        .whereType<SurahSummary>()
        .toList();
  });
});
