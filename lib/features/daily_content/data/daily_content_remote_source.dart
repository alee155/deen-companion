import 'package:dio/dio.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/api_endpoints.dart';
import '../../hadith/data/models/hadith_model.dart';
import '../domain/entities/daily_content.dart';

class DailyContentRemoteSource {
  final Dio dio;
  const DailyContentRemoteSource(this.dio);

  Future<DailyAyah> getAyah(int surah, int ayah) async {
    try {
      final response = await dio.get(ApiEndpoints.quranAyah(surah, ayah));
      final data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final surahJson = data['surah'] as Map<String, dynamic>;
      final verse = data['verse'] as Map<String, dynamic>;
      final translations = Map<String, dynamic>.from(
        verse['translations'] as Map,
      );
      return DailyAyah(
        surahNumber: surahJson['number'] as int,
        surahNameEnglish: surahJson['name_english'] as String,
        surahNameArabic: surahJson['name_arabic'] as String,
        ayahNumber: verse['ayah'] as int,
        arabic: verse['arabic'] as String,
        translation: _stripFootnotes(
          translations['sahih_international'] as String? ?? '',
        ),
      );
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  Future<HadithModel> getHadith(String collection, int number) async {
    try {
      final response = await dio.get(
        ApiEndpoints.hadithByNumber(collection, number),
      );
      final data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return HadithModel.fromJson(data);
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  /// The translation carries inline footnote markers ("Ever-Living,1 the
  /// Self-Sustaining.2") that read as stray digits in a notification.
  static String _stripFootnotes(String text) => text.replaceAllMapped(
    RegExp(r'(?<=[A-Za-z,.;:!?”’)])\d{1,2}(?=[\s,.;:!?”’)]|$)'),
    (_) => '',
  );
}
