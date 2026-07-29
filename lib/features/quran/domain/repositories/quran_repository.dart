import '../../../../core/usecase/usecase.dart';
import '../entities/quran_meta.dart';
import '../entities/surah_summary.dart';
import '../entities/juz.dart';
import '../entities/mushaf_page.dart';
import '../entities/search_result.dart';

abstract class QuranRepository {
  // ── Synchronous cache reads — return instantly, or null if nothing cached yet ──
  QuranMeta? getCachedQuranMeta();
  List<SurahSummary>? getCachedSurahList();
  Juz? getCachedJuz(int number);
  MushafPage? getCachedMushafPage(int number);
  List<SearchResult>? getCachedSearchResults(
    String query, {
    String translation = 'sahih_international',
    int limit = 25,
  });

  // ── Fetch + cache — hits network, caches result, falls back to existing
  //    cache on failure so a transient error never blanks the screen ──
  Future<Result<QuranMeta>> fetchAndCacheQuranMeta({bool forceRefresh = false});
  Future<Result<List<SurahSummary>>> fetchAndCacheSurahList({
    bool forceRefresh = false,
  });
  Future<Result<Juz>> fetchAndCacheJuz(int number, {bool forceRefresh = false});
  Future<Result<MushafPage>> fetchAndCacheMushafPage(
    int number, {
    bool forceRefresh = false,
  });
  Future<Result<List<SearchResult>>> search(
    String query, {
    String translation = 'sahih_international',
    int limit = 25,
    bool forceRefresh = false,
  });
}
