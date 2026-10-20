import 'package:deen_companion/features/favorites/domain/entities/favorite_item.dart';
import 'package:deen_companion/features/favorites/domain/favorites_filter.dart';
import 'package:deen_companion/features/favorites/presentation/widgets/favorite_row.dart';
import 'package:flutter_test/flutter_test.dart';

FavoriteItem fav(
  FavoriteContentType type,
  String ref, {
  String? subtitle,
  int day = 1,
}) => FavoriteItem(
  id: FavoriteItem.buildId(type, ref),
  type: type,
  referenceId: ref,
  title: 'Title $ref',
  subtitle: subtitle,
  route: '/r/$ref',
  savedAt: DateTime.utc(2024, 1, day),
);

void main() {
  final all = [
    fav(FavoriteContentType.surah, 'a', subtitle: 'The Opening', day: 1),
    fav(FavoriteContentType.surah, 'b', day: 3),
    fav(FavoriteContentType.dua, 'c', subtitle: 'Morning', day: 2),
    fav(FavoriteContentType.hadith, 'd', day: 4),
  ];

  group('filterFavorites', () {
    test('no filter returns everything, newest first', () {
      expect(filterFavorites(all).map((e) => e.referenceId), [
        'd',
        'b',
        'c',
        'a',
      ]);
    });

    test('filters by type', () {
      final r = filterFavorites(all, type: FavoriteContentType.surah);
      expect(r.map((e) => e.referenceId), ['b', 'a']);
    });

    test('searches title and subtitle, ignoring case and spaces', () {
      expect(
        filterFavorites(all, query: '  OPENING ').map((e) => e.referenceId),
        ['a'],
      );
      expect(filterFavorites(all, query: 'title c').map((e) => e.referenceId), [
        'c',
      ]);
    });

    test('type and query combine', () {
      expect(
        filterFavorites(all, type: FavoriteContentType.dua, query: 'opening'),
        isEmpty,
      );
    });

    test('does not modify the list it is given', () {
      final copy = List.of(all);
      filterFavorites(all);
      expect(all, copy);
    });
  });

  group('countFavoritesByType', () {
    test('counts only types that have favorites, in enum order', () {
      final counts = countFavoritesByType(all);
      expect(counts.keys.toList(), [
        FavoriteContentType.surah,
        FavoriteContentType.hadith,
        FavoriteContentType.dua,
      ]);
      expect(counts[FavoriteContentType.surah], 2);
    });

    test('empty list gives empty map', () {
      expect(countFavoritesByType(const []), isEmpty);
    });
  });

  group('favoriteSavedLabel', () {
    final now = DateTime(2024, 3, 20, 12);
    test('relative for recent saves', () {
      expect(favoriteSavedLabel(now, now: now), 'just now');
      expect(
        favoriteSavedLabel(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        favoriteSavedLabel(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        favoriteSavedLabel(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
    });

    test('a date once over a week old', () {
      expect(favoriteSavedLabel(DateTime(2024, 3, 1), now: now), '1 Mar 2024');
    });
  });
}
