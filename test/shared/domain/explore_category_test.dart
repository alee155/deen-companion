import 'dart:io';

import 'package:deen_companion/core/theme/app_colors.dart';
import 'package:deen_companion/shared/domain/explore_category.dart';
import 'package:deen_companion/shared/domain/explore_icon_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final all = ExploreCatalog.all;

  test('ids and routes are unique and routes are absolute', () {
    expect(all.map((c) => c.id).toSet(), hasLength(all.length));
    expect(all.map((c) => c.route).toSet(), hasLength(all.length));
    for (final c in all) {
      expect(c.route, startsWith('/'));
      expect(c.label, isNotEmpty);
      expect(c.description, isNotEmpty);
      expect(c.group, isNotEmpty);
    }
  });

  test('homePreviewIds all reference real categories, no duplicates', () {
    final ids = all.map((c) => c.id).toSet();
    expect(
      ExploreCatalog.homePreviewIds.toSet(),
      hasLength(ExploreCatalog.homePreviewIds.length),
    );
    for (final id in ExploreCatalog.homePreviewIds) {
      expect(ids, contains(id));
    }
  });

  test('every category has an icon asset that exists on disk', () {
    for (final c in all) {
      final path = exploreIconAssets[c.id];
      expect(path, isNotNull, reason: 'no icon asset for ${c.id}');
      expect(File(path!).existsSync(), isTrue, reason: '$path missing');
    }
  });

  test('icon asset map has no orphan ids', () {
    final ids = all.map((c) => c.id).toSet();
    expect(ids.containsAll(exploreIconAssets.keys), isTrue);
  });

  test('accent resolves to palette colours', () {
    expect(ExploreAccent.quran.color, AppColors.quranAccent);
    expect(ExploreAccent.tools.background, AppColors.toolsAccentBg);
    for (final a in ExploreAccent.values) {
      expect(a.color, isNotNull);
      expect(a.background, isNotNull);
    }
    final z = all.firstWhere((c) => c.id == 'zakat');
    expect(z.accentColor, ExploreAccent.tools.color);
    expect(z.accentBg, ExploreAccent.tools.background);
  });

  test('categories sharing a group are contiguous', () {
    final seen = <String>[];
    for (final c in all) {
      if (seen.isEmpty || seen.last != c.group) seen.add(c.group);
    }
    expect(seen.toSet(), hasLength(seen.length));
  });
}
