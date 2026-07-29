import 'package:equatable/equatable.dart';

/// Every kind of content in the app that can be favorited. Add new values
/// here as new content types grow a "favorite" action — the rest of the
/// Favorites feature (storage, list screen, grouping) needs no changes.
enum FavoriteContentType {
  surah,
  hadith,
  dua,
  asmaName,
  islamicName,
  juz;

  String get label {
    switch (this) {
      case FavoriteContentType.surah:
        return 'Surahs';
      case FavoriteContentType.hadith:
        return 'Hadith';
      case FavoriteContentType.dua:
        return 'Duas';
      case FavoriteContentType.asmaName:
        return 'Names of Allah';
      case FavoriteContentType.islamicName:
        return 'Islamic Names';
      case FavoriteContentType.juz:
        return 'Juz';
    }
  }
}

/// A single favorited item. [id] must be stable and globally unique across
/// content types (callers build it as `'${type.name}:$referenceId'`, see
/// [FavoriteItem.buildId]) since it doubles as the local-storage key.
class FavoriteItem extends Equatable {
  final String id;
  final FavoriteContentType type;
  final String referenceId;
  final String title;
  final String? subtitle;

  /// Route to push when the user taps this favorite (e.g. `/hadith/read/bukhari`).
  final String route;
  final DateTime savedAt;

  const FavoriteItem({
    required this.id,
    required this.type,
    required this.referenceId,
    required this.title,
    this.subtitle,
    required this.route,
    required this.savedAt,
  });

  static String buildId(FavoriteContentType type, String referenceId) =>
      '${type.name}:$referenceId';

  @override
  List<Object?> get props => [id, type, referenceId, title, subtitle, route, savedAt];
}
