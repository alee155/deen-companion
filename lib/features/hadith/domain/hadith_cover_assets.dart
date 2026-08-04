/// Maps a collection key to its cover artwork.
///
/// Returns null when a collection has no artwork of its own — the card then
/// draws a designed fallback cover instead. The previous version pointed every
/// unmapped key at `default.png`, a file that isn't in the bundle, so the
/// three 40-hadith collections (Nawawi, Qudsi, Dehlawi) rendered a broken
/// image box.
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

  /// Null when there is no artwork for [collectionKey].
  static String? forKey(String collectionKey) => _covers[collectionKey];

  static bool hasCover(String collectionKey) =>
      _covers.containsKey(collectionKey);
}
