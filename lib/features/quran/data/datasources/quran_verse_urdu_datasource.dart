import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';

/// Fetches the Urdu translation of a single verse.
///
/// For screens whose data comes without Urdu (Mutashabihat, search): the verse
/// is looked up by its key, from the same source and translation the Juz
/// reader and the daily verse use, so one verse never reads two ways.
class QuranVerseUrduDataSource {
  final Dio _dio;
  const QuranVerseUrduDataSource(this._dio);

  /// The Urdu text; `''` when the source has none; `null` when we couldn't
  /// find out (offline, error) so the caller doesn't remember it as "none".
  Future<String?> fetch(int surah, int ayah) async {
    try {
      final response = await _dio.get<Object?>(
        ApiEndpoints.quranAyah(surah, ayah),
      );
      final body = response.data;
      if (body is! Map) return null;
      final data = body['data'];
      final verse = data is Map ? data['verse'] : null;
      final translations = verse is Map ? verse['translations'] : null;
      final urdu = translations is Map ? translations['urdu'] : null;
      return urdu is String ? urdu.trim() : '';
    } catch (_) {
      return null;
    }
  }
}
