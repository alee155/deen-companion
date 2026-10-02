import 'package:deen_companion/features/quran/data/models/juz_model.dart';
import 'package:deen_companion/features/quran/data/models/mushaf_page_model.dart';
import 'package:deen_companion/features/quran/data/models/quran_meta_model.dart';
import 'package:deen_companion/features/quran/data/models/search_response_model.dart';
import 'package:deen_companion/features/quran/data/models/search_result_model.dart';
import 'package:deen_companion/features/quran/data/models/surah_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/quran_fixtures.dart';

void main() {
  group('SurahSummaryModel', () {
    test('parses JSON and maps audio.example_audio to exampleAudioUrl', () {
      final model = SurahSummaryModel.fromJson(surahJson(number: 2));
      final entity = model.toEntity();

      expect(model.number, 2);
      expect(model.bismillahPre, isFalse);
      expect(model.audio.recitersAvailable, 3);
      expect(entity.exampleAudioUrl, 'https://a/2.mp3');
      expect(entity.versesCount, 7);
    });

    test('toJson round-trips through fromJson', () {
      final json = surahJson();
      expect(SurahSummaryModel.fromJson(json).toJson(), json);
    });

    test('throws on missing required field', () {
      final json = surahJson()..remove('name_arabic');
      expect(() => SurahSummaryModel.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('throws when audio block is missing', () {
      final json = surahJson()..remove('audio');
      expect(() => SurahSummaryModel.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('throws on wrong field type', () {
      final json = surahJson()..['number'] = '1';
      expect(() => SurahSummaryModel.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('QuranMetaModel', () {
    test('parses meta with nested reciters and translations', () {
      final entity = QuranMetaModel.fromJson(metaJson()).toEntity();

      expect(entity.totalSurahs, 114);
      expect(entity.totalPages, 604);
      expect(entity.translationsAvailable, [
        'sahih_international',
        'pickthall',
      ]);
      expect(entity.reciters.single.name, 'Alafasy');
    });

    test('round-trips through toJson', () {
      final json = metaJson();
      expect(QuranMetaModel.fromJson(json).toJson(), json);
    });

    test('empty reciters list is allowed', () {
      final json = metaJson()..['reciters'] = [];
      expect(QuranMetaModel.fromJson(json).reciters, isEmpty);
    });

    test('missing reciters throws', () {
      final json = metaJson()..remove('reciters');
      expect(() => QuranMetaModel.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('JuzModel', () {
    test('parses verses including empty translation map', () {
      final juz = JuzModel.fromJson(juzJson(number: 5)).toEntity();

      expect(juz.juzNumber, 5);
      expect(juz.verses, hasLength(2));
      expect(
        juz.verses.first.translations['sahih_international'],
        'In the name',
      );
      expect(juz.verses.last.translations, isEmpty);
    });

    test('round-trips through toJson', () {
      final json = juzJson();
      expect(JuzModel.fromJson(json).toJson(), json);
    });

    test('malformed verse entry throws', () {
      final json = juzJson()..['verses'] = ['not a map'];
      expect(() => JuzModel.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('MushafPageModel / MushafPage', () {
    test('parses words and exposes wordsByLine grouping', () {
      final page = MushafPageModel.fromJson(pageJson(page: 3)).toEntity();

      expect(page.page, 3);
      expect(page.linesPerPage, 15);
      final byLine = page.wordsByLine;
      expect(byLine.keys, [1, 2]);
      expect(byLine[1]!.map((w) => w.position), [1, 2]);
      expect(byLine[2]!.single.textUthmaniTajweed, '<t>w3</t>');
    });

    test('wordsByLine is empty for a page with no words', () {
      final page = MushafPageModel.fromJson(
        pageJson()..['words'] = [],
      ).toEntity();
      expect(page.wordsByLine, isEmpty);
    });

    test('round-trips through toJson', () {
      final json = pageJson();
      expect(MushafPageModel.fromJson(json).toJson(), json);
    });
  });

  group('Search models', () {
    test('SearchResultModel parses and drops matchedIn in entity', () {
      final model = SearchResultModel.fromJson(searchResultJson());
      expect(model.matchedIn, 'translation');
      expect(model.toEntity().verseKey, '2:255');
      expect(model.toJson(), searchResultJson());
    });

    test('SearchResponseModel parses results list', () {
      final model = SearchResponseModel.fromJson(searchResponseJson());
      expect(model.query, 'throne');
      expect(model.searchedIn, ['translation']);
      expect(model.results.single.surahName, 'Al-Baqarah');
      expect(model.toJson(), searchResponseJson());
    });

    test('SearchResponseModel without results throws', () {
      final json = searchResponseJson()..remove('results');
      expect(
        () => SearchResponseModel.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
