import 'package:deen_companion/features/hadith/data/models/daily_hadith_cache_model.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_collection_model.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_list_page_model.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/hadith_fixtures.dart';

void main() {
  group('HadithModel (beyond the reader tests)', () {
    test('non-string values are stringified, null becomes empty', () {
      final m = HadithModel.fromJson({
        'id': 12,
        'collection': null,
        'grade': 4.5,
      });
      expect(m.id, '12');
      expect(m.collection, '');
      expect(m.grade, '4.5');
    });

    test('unparseable hadith number defaults to 0', () {
      expect(HadithModel.fromJson({'hadithnumber': 'abc'}).hadithNumber, 0);
      expect(HadithModel.fromJson({'hadithnumber': true}).hadithNumber, 0);
    });

    test('decimal strings round to nearest int', () {
      expect(HadithModel.fromJson({'hadithnumber': '402.6'}).hadithNumber, 403);
    });

    test('toEntity carries every field', () {
      final e = HadithModel.fromJson(
        hadithJson(n: 7, grade: "Da'if"),
      ).toEntity();
      expect(e.id, 'bukhari:7');
      expect(e.hadithNumber, 7);
      expect(e.grade, "Da'if");
      expect(e.collectionName, 'Sahih al-Bukhari');
    });
  });

  group('HadithCollectionModel', () {
    test('parses, converts and round-trips', () {
      final m = HadithCollectionModel.fromJson(hadithCollectionJson());
      expect(m.toEntity().totalHadiths, 7563);
      expect(m.toEntity().arabicName, 'صحيح البخاري');
      expect(m.toJson(), hadithCollectionJson());
    });

    test('strict: missing field throws', () {
      expect(
        () => HadithCollectionModel.fromJson(
          hadithCollectionJson()..remove('author'),
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('HadithListPageModel', () {
    test('parses a page and tolerates sloppy hadith entries inside', () {
      final json = hadithPageJson()
        ..['hadiths'] = [hadithJson(), <String, dynamic>{}];
      final m = HadithListPageModel.fromJson(json);
      expect(m.hadiths, hasLength(2));
      expect(m.hadiths.last.hadithNumber, 0);
      expect(m.totalPages, 3);
    });

    test('round-trips through toJson', () {
      final json = hadithPageJson();
      expect(HadithListPageModel.fromJson(json).toJson(), json);
    });

    test('missing pagination fields throw', () {
      expect(
        () => HadithListPageModel.fromJson(
          hadithPageJson()..remove('total_pages'),
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('DailyHadithCacheModel', () {
    test('round-trips date and hadith', () {
      final json = {'date': '2025-01-05', 'hadith': hadithJson()};
      final m = DailyHadithCacheModel.fromJson(json);
      expect(m.date, '2025-01-05');
      expect(m.hadith.id, 'bukhari:1');
      expect(m.toJson(), json);
    });

    test('missing hadith throws', () {
      expect(
        () => DailyHadithCacheModel.fromJson({'date': 'x'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
