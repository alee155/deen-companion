/// Maps a collection key to its asset cover. Add your image files under
/// assets/images/hadith_covers/{key}.png using these exact keys, then
/// register the folder in pubspec.yaml assets.
class HadithCoverAssets {
  HadithCoverAssets._();

  static const _basePath = 'assets/images/hadith_covers';

  static const Map<String, String> _covers = {
    'bukhari': '$_basePath/sahih_al_bukhari.jpg',
    'muslim': '$_basePath/sahih_muslim.jpeg',
    'abudawud': '$_basePath/sunan_abu_dawud.jpeg',
    'tirmidhi': '$_basePath/jami_at_tirmidhi.jpg',
    'ibnmajah': '$_basePath/sunan_ibn_majah.jpg',
    'nasai': '$_basePath/sunan_an_nasa.jpg',
    'malik': '$_basePath/muwatta_malik.jpg',
  };

  static const String _fallback = '$_basePath/default.png';

  static String forKey(String collectionKey) =>
      _covers[collectionKey] ?? _fallback;
}
