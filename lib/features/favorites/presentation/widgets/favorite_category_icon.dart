import 'package:flutter/material.dart';
import '../../../../shared/domain/explore_icon_assets.dart';
import '../../domain/entities/favorite_item.dart';

/// Which Explore category each favorite content type corresponds to — lets
/// the Favorites list reuse Explore's own icon assets instead of choosing
/// its own, so the same content reads as the same icon everywhere.
const Map<FavoriteContentType, String> _exploreCategoryIdFor = {
  FavoriteContentType.surah: 'quran',
  FavoriteContentType.hadith: 'hadith',
  FavoriteContentType.dua: 'duas',
  FavoriteContentType.asmaName: 'names_of_allah',
  FavoriteContentType.islamicName: 'islamic_names',
  FavoriteContentType.juz: 'juz',
};

/// The illustrated icon Explore shows for this content type, when one
/// exists. Prefer this over [favoriteCategoryIcon] wherever there's room to
/// render an image.
String? favoriteCategoryIconAsset(FavoriteContentType type) =>
    exploreIconAssets[_exploreCategoryIdFor[type]];

/// Material-icon fallback, matching Explore's own fallback icon for the same
/// category — used only if [favoriteCategoryIconAsset] returns null.
IconData favoriteCategoryIcon(FavoriteContentType type) {
  switch (type) {
    case FavoriteContentType.surah:
      return Icons.menu_book_outlined;
    case FavoriteContentType.hadith:
      return Icons.format_quote;
    case FavoriteContentType.dua:
      return Icons.back_hand_outlined;
    case FavoriteContentType.asmaName:
      return Icons.auto_awesome_outlined;
    case FavoriteContentType.islamicName:
      return Icons.badge_outlined;
    case FavoriteContentType.juz:
      return Icons.auto_stories_outlined;
  }
}
