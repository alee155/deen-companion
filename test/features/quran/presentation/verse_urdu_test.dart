import 'dart:async';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/features/quran/data/datasources/quran_verse_urdu_datasource.dart';
import 'package:deen_companion/features/quran/domain/entities/search_result.dart';
import 'package:deen_companion/features/quran/presentation/providers/verse_urdu_provider.dart';
import 'package:deen_companion/features/quran/presentation/widgets/search_result_tile.dart';
import 'package:deen_companion/features/quran/presentation/widgets/verse_translation_text.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/fake_storage.dart';

const _en = 'Allah - there is no deity except Him.';
const _ur = 'اللہ ہی معبود ہے اس کے سوا کوئی معبود نہیں';

class _Source implements QuranVerseUrduDataSource {
  final Future<String?> Function(int, int) handler;
  final calls = <String>[];
  _Source(this.handler);
  @override
  Future<String?> fetch(int surah, int ayah) {
    calls.add('$surah:$ayah');
    return handler(surah, ayah);
  }
}

void main() {
  late FakeStorage storage;
  setUp(() => storage = FakeStorage());

  ProviderContainer make(_Source source) {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        quranVerseUrduDataSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('parseVerseKey', () {
    test(
      'reads surah and ayah',
      () => expect(parseVerseKey('2:255'), (2, 255)),
    );
    test('rejects anything else', () {
      for (final bad in ['', '2', '2:x', 'a:1', '1:2:3']) {
        expect(parseVerseKey(bad), isNull, reason: bad);
      }
    });
  });

  group('quranVerseUrduProvider', () {
    test('fetches once, then reads it from the saved copy', () async {
      final source = _Source((_, _) async => _ur);
      expect(
        await make(source).read(quranVerseUrduProvider('2:255').future),
        _ur,
      );
      expect(
        await make(source).read(quranVerseUrduProvider('2:255').future),
        _ur,
      );
      expect(source.calls, ['2:255']);
    });

    test('a confirmed "none" is remembered; a failure is not', () async {
      final none = _Source((_, _) async => '');
      await make(none).read(quranVerseUrduProvider('1:1').future);
      await make(none).read(quranVerseUrduProvider('1:1').future);
      expect(none.calls, hasLength(1));

      final fail = _Source((_, _) async => null);
      await expectLater(
        make(fail).read(quranVerseUrduProvider('1:2').future),
        throwsA(isA<VerseUrduLoadFailure>()),
      );
      await expectLater(
        make(fail).read(quranVerseUrduProvider('1:2').future),
        throwsA(isA<VerseUrduLoadFailure>()),
      );
      expect(fail.calls, hasLength(2));
      expect(
        storage.boxes[AppConstants.apiCacheBoxName]?.keys,
        isNot(contains('quran_urdu_1_2')),
      );
    });

    test('a bad key makes no request', () async {
      final source = _Source((_, _) async => _ur);
      expect(
        await make(source).read(quranVerseUrduProvider('nope').future),
        '',
      );
      expect(source.calls, isEmpty);
    });
  });

  group('QuranVerseUrduDataSource', () {
    Dio dioReturning(Object? body, {bool throws = false}) {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => throws
              ? h.reject(DioException(requestOptions: o))
              : h.resolve(
                  Response(requestOptions: o, data: body, statusCode: 200),
                ),
        ),
      );
      return dio;
    }

    test('reads translations.urdu from the ayah payload', () async {
      final body = {
        'data': {
          'verse': {
            'translations': {'urdu': '  $_ur  ', 'sahih_international': _en},
          },
        },
      };
      expect(
        await QuranVerseUrduDataSource(dioReturning(body)).fetch(2, 255),
        _ur,
      );
    });

    test(
      'no urdu key is "none"; a bad body or a failure is "unknown"',
      () async {
        final noUrdu = {
          'data': {
            'verse': {
              'translations': {'x': 'y'},
            },
          },
        };
        expect(
          await QuranVerseUrduDataSource(dioReturning(noUrdu)).fetch(1, 1),
          '',
        );
        expect(
          await QuranVerseUrduDataSource(dioReturning('oops')).fetch(1, 1),
          isNull,
        );
        expect(
          await QuranVerseUrduDataSource(
            dioReturning(null, throws: true),
          ).fetch(1, 1),
          isNull,
        );
      },
    );
  });

  group('VerseTranslationText and SearchResultTile', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      required _Source source,
      String language = 'english',
    }) async {
      storage.boxes[AppConstants.settingsBoxName] = {
        'reader_translation_language': language,
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            quranVerseUrduDataSourceProvider.overrideWithValue(source),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(body: child),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const text = VerseTranslationText(
      verseKey: '2:255',
      english: _en,
      englishStyle: TextStyle(fontSize: 14),
    );

    testWidgets('English: the English text, no request', (tester) async {
      final source = _Source((_, _) async => _ur);
      await pump(tester, text, source: source);
      expect(find.text(_en), findsOneWidget);
      expect(source.calls, isEmpty);
    });

    testWidgets('Urdu: the Urdu text, right-to-left, in Nastaliq', (
      tester,
    ) async {
      final source = _Source((_, _) async => _ur);
      await pump(tester, text, source: source, language: 'urdu');
      final t = tester.widget<Text>(find.text(_ur));
      expect(t.textDirection, TextDirection.rtl);
      expect(t.style?.fontFamily, 'NotoNastaliqUrdu');
      expect(find.text(_en), findsNothing);
    });

    testWidgets('Urdu: while loading, the English is never shown', (
      tester,
    ) async {
      final gate = Completer<String?>();
      final source = _Source((_, _) => gate.future);
      storage.boxes[AppConstants.settingsBoxName] = {
        'reader_translation_language': 'urdu',
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            quranVerseUrduDataSourceProvider.overrideWithValue(source),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: text),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_en), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete(_ur);
      await tester.pumpAndSettle();
      expect(find.text(_ur), findsOneWidget);
    });

    testWidgets('Urdu chosen, none exists: says so, no English', (
      tester,
    ) async {
      final source = _Source((_, _) async => '');
      await pump(tester, text, source: source, language: 'urdu');
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_en), findsNothing);
    });

    testWidgets('Urdu chosen, could not load: says so and offers a retry', (
      tester,
    ) async {
      var ok = false;
      final source = _Source((_, _) async => ok ? _ur : null);
      await pump(tester, text, source: source, language: 'urdu');
      expect(
        find.textContaining('Couldn’t load the Urdu translation'),
        findsOneWidget,
      );
      expect(find.text(_en), findsNothing);

      ok = true;
      await tester.tap(find.textContaining('Couldn’t load'));
      await tester.pumpAndSettle();
      expect(find.text(_ur), findsOneWidget);
    });

    testWidgets('a search result from an Urdu search shows its own Urdu', (
      tester,
    ) async {
      final source = _Source((_, _) async => 'unused');
      await pump(
        tester,
        const SearchResultTile(
          result: SearchResult(
            verseKey: '2:255',
            surahNumber: 2,
            surahName: 'Al-Baqarah',
            ayah: 255,
            arabic: 'ar',
            transliteration: 't',
            translation: _ur,
            translationSource: 'urdu',
          ),
        ),
        source: source,
        language: 'urdu',
      );
      expect(find.text(_ur), findsOneWidget);
      expect(source.calls, isEmpty, reason: 'already Urdu: no second lookup');
    });

    testWidgets('an English-matched result is shown in Urdu when chosen', (
      tester,
    ) async {
      final source = _Source((_, _) async => _ur);
      await pump(
        tester,
        const SearchResultTile(
          result: SearchResult(
            verseKey: '2:255',
            surahNumber: 2,
            surahName: 'Al-Baqarah',
            ayah: 255,
            arabic: 'ar',
            transliteration: 't',
            translation: _en,
          ),
        ),
        source: source,
        language: 'urdu',
      );
      expect(find.text(_ur), findsOneWidget);
      expect(find.text(_en), findsNothing);
      expect(source.calls, ['2:255']);
    });
  });
}
