import '../../../../core/usecase/usecase.dart';
import '../entities/mutashabihat_entry.dart';
import '../entities/mutashabihat_info.dart';
import '../entities/mutashabihat_surah_page.dart';

abstract class MutashabihatRepository {
  MutashabihatInfo? getCachedInfo();
  Future<Result<MutashabihatInfo>> fetchAndCacheInfo({
    bool forceRefresh = false,
  });

  Future<Result<MutashabihatEntry>> fetchRandom();
  Future<Result<MutashabihatEntry>> fetchByAyah(int surah, int ayah);
  Future<Result<MutashabihatSurahPage>> fetchSurahPage(
    int surah,
    int page, {
    bool forceRefresh = false,
  });
}
