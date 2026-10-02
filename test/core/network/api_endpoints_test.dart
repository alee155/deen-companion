import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = 'https://ummahapi.com/api';

  test('simple path builders', () {
    expect(ApiEndpoints.quranJuz(5), '$base/quran/juz/5');
    expect(ApiEndpoints.quranMushafPage(604), '$base/quran/page/604');
    expect(ApiEndpoints.asmaUlHusnaByNumber(99), '$base/asma-ul-husna/99');
    expect(ApiEndpoints.asmaUlHusnaDaily(3), '$base/asma-ul-husna/daily/3');
    expect(
      ApiEndpoints.mutashabihatByAyah(2, 255),
      '$base/quran/mutashabihat/2/255',
    );
    expect(
      ApiEndpoints.hadithPage('bukhari', 3),
      '$base/hadith/bukhari?page=3',
    );
    expect(ApiEndpoints.hadithByNumber('muslim', 10), '$base/hadith/muslim/10');
    expect(ApiEndpoints.duasCategory('morning'), '$base/duas/category/morning');
    expect(
      ApiEndpoints.timingsByTimestamp(1700000000),
      'https://api.aladhan.com/v1/timings/1700000000',
    );
  });

  test('qibla encodes lat/lng', () {
    final u = Uri.parse(ApiEndpoints.qibla(lat: 31.5, lng: -74.3));
    expect(u.path, '/api/qibla');
    expect(u.queryParameters, {'lat': '31.5', 'lng': '-74.3'});
  });

  test('query values are percent-encoded', () {
    final s = ApiEndpoints.quranSearch('a b&c=d');
    expect(s, isNot(contains('a b')));
    expect(Uri.parse(s).queryParameters['q'], 'a b&c=d');
    expect(
      Uri.parse(ApiEndpoints.duasSearch('x y')).queryParameters['q'],
      'x y',
    );
    expect(
      Uri.parse(ApiEndpoints.asmaUlHusnaSearch('رحمن')).queryParameters['q'],
      'رحمن',
    );
  });

  group('quranSurahDetail', () {
    test('no params -> no query string', () {
      expect(ApiEndpoints.quranSurahDetail(1), '$base/quran/surah/1');
    });
    test('includes only supplied params', () {
      final u = Uri.parse(
        ApiEndpoints.quranSurahDetail(2, script: 'uthmani', reciter: 3),
      );
      expect(u.queryParameters, {'script': 'uthmani', 'reciter': '3'});
    });
  });

  test('quranAyah optional script', () {
    expect(ApiEndpoints.quranAyah(1, 2), '$base/quran/surah/1/ayah/2');
    expect(
      Uri.parse(ApiEndpoints.quranAyah(1, 2, script: 'x')).queryParameters,
      {'script': 'x'},
    );
  });

  test('quranSearch optional params', () {
    final u = Uri.parse(
      ApiEndpoints.quranSearch('mercy', translation: 'sahih', limit: 5),
    );
    expect(u.queryParameters, {
      'q': 'mercy',
      'translation': 'sahih',
      'limit': '5',
    });
    expect(Uri.parse(ApiEndpoints.quranSearch('m')).queryParameters, {
      'q': 'm',
    });
  });

  test('mutashabihatBySurah defaults and overrides', () {
    expect(Uri.parse(ApiEndpoints.mutashabihatBySurah(2)).queryParameters, {
      'page': '1',
      'limit': '20',
    });
    expect(
      Uri.parse(
        ApiEndpoints.mutashabihatBySurah(2, page: 3, limit: 5),
      ).queryParameters,
      {'page': '3', 'limit': '5'},
    );
  });

  test('zakatNisab optional prices', () {
    expect(ApiEndpoints.zakatNisab(), '$base/zakat/nisab');
    expect(
      Uri.parse(
        ApiEndpoints.zakatNisab(goldPricePerGram: 60.5),
      ).queryParameters,
      {'gold_price_per_gram': '60.5'},
    );
    expect(
      Uri.parse(
        ApiEndpoints.zakatNisab(goldPricePerGram: 1, silverPricePerGram: 2),
      ).queryParameters.keys,
      containsAll(['gold_price_per_gram', 'silver_price_per_gram']),
    );
  });

  test('hijriDate zero-pads', () {
    expect(
      Uri.parse(
        ApiEndpoints.hijriDate(year: 1445, month: 3, day: 7),
      ).queryParameters['date'],
      '1445-03-07',
    );
    expect(
      Uri.parse(
        ApiEndpoints.hijriDate(year: 5, month: 1, day: 1),
      ).queryParameters['date'],
      '0005-01-01',
    );
  });

  test('gregorianDate params', () {
    expect(
      Uri.parse(
        ApiEndpoints.gregorianDate(year: 2024, month: 3, day: 7),
      ).queryParameters,
      {'year': '2024', 'month': '3', 'day': '7'},
    );
  });

  test('hadithSearch default limit and optional collection', () {
    expect(Uri.parse(ApiEndpoints.hadithSearch('x')).queryParameters, {
      'q': 'x',
      'limit': '25',
    });
    expect(
      Uri.parse(
        ApiEndpoints.hadithSearch('x', collection: 'bukhari', limit: 5),
      ).queryParameters,
      {'q': 'x', 'collection': 'bukhari', 'limit': '5'},
    );
  });
}
