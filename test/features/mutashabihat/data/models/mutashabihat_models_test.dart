import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_entry_model.dart';
import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_info_model.dart';
import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_surah_page_model.dart';
import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_verse_ref_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/mutashabihat_fixtures.dart';

void main() {
  group('MutashabihatVerseRefModel', () {
    test('parses and round-trips', () {
      final m = MutashabihatVerseRefModel.fromJson(verseRefJson());
      expect(m.verseKey, '2:1');
      expect(m.toJson(), verseRefJson());
      expect(m.toEntity().surahNameEnglish, 'Al-Baqarah');
    });

    test('ignores extra keys such as similar_verses', () {
      final m = MutashabihatVerseRefModel.fromJson(entryJson());
      expect(m.verseKey, '2:1');
    });

    test('missing field throws', () {
      expect(
        () => MutashabihatVerseRefModel.fromJson(
          verseRefJson()..remove('arabic'),
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('MutashabihatEntryModel', () {
    test('base verse is read from the outer object, similar from the list', () {
      final m = MutashabihatEntryModel.fromJson(entryJson(similar: 3));
      expect(m.verse.verseKey, '2:1');
      expect(m.similarVerses.map((v) => v.verseKey), ['3:1', '3:2', '3:3']);
    });

    test(
      'toJson flattens the base verse and nests similar_verses (round trip)',
      () {
        final json = entryJson();
        expect(MutashabihatEntryModel.fromJson(json).toJson(), json);
      },
    );

    test('empty similar list is allowed; missing list throws', () {
      expect(
        MutashabihatEntryModel.fromJson(
          entryJson(similar: 0),
        ).toEntity().similarVerses,
        isEmpty,
      );
      expect(
        () => MutashabihatEntryModel.fromJson(verseRefJson()),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('MutashabihatInfoModel', () {
    test('parses and round-trips', () {
      final m = MutashabihatInfoModel.fromJson(infoJson());
      expect(m.toEntity().totalPairs, 2500);
      expect(m.toJson(), infoJson());
    });

    test('wrong types throw', () {
      expect(
        () => MutashabihatInfoModel.fromJson(
          infoJson()..['total_pairs'] = '2500',
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('MutashabihatSurahPageModel / entity', () {
    test('verses key maps to entries', () {
      final e = MutashabihatSurahPageModel.fromJson(
        surahPageJson(count: 3),
      ).toEntity();
      expect(e.entries, hasLength(3));
      expect(e.surah, 2);
    });

    test('round-trips', () {
      final json = surahPageJson();
      expect(MutashabihatSurahPageModel.fromJson(json).toJson(), json);
    });

    test('hasMore is true only while page < totalPages', () {
      MutashabihatSurahPageModel.fromJson(
        surahPageJson(page: 1, totalPages: 2),
      ).toEntity();
      expect(
        MutashabihatSurahPageModel.fromJson(
          surahPageJson(page: 1, totalPages: 2),
        ).toEntity().hasMore,
        isTrue,
      );
      expect(
        MutashabihatSurahPageModel.fromJson(
          surahPageJson(page: 2, totalPages: 2),
        ).toEntity().hasMore,
        isFalse,
      );
      expect(
        MutashabihatSurahPageModel.fromJson(
          surahPageJson(page: 1, totalPages: 0),
        ).toEntity().hasMore,
        isFalse,
      );
    });
  });
}
