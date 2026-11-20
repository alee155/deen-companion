import 'dart:convert';
import 'dart:typed_data';

import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/features/hadith/data/datasources/hadith_urdu_datasource.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/features/hadith/presentation/providers/hadith_urdu_providers.dart';
import 'package:deen_companion/features/hadith/presentation/widgets/hadith_reader_page.dart';
import 'package:deen_companion/shared/providers/reading_preferences_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/fake_storage.dart';

const _urdu = 'اعمال کا دارومدار نیتوں پر ہے';

Hadith _hadith({
  String id = 'bukhari-1',
  String collection = 'bukhari',
  String english = 'Narrated Umar: Deeds are judged by intentions.',
}) => Hadith(
  id: id,
  collection: collection,
  collectionName: 'Sahih al-Bukhari',
  hadithNumber: 1,
  arabic: 'إنما الأعمال بالنيات',
  english: english,
  grade: 'Sahih',
);

/// Answers every request through [handler] and counts them.
class _Adapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  final requests = <Uri>[];
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _ok(String text) => _json({
  'metadata': {'name': 'Sahih al Bukhari'},
  'hadiths': [
    {'hadithnumber': 1, 'text': text},
  ],
});

HadithUrduDataSource _source(_Adapter adapter) => HadithUrduDataSource(
  dio: HadithUrduDataSource.createClient()..httpClientAdapter = adapter,
);

void main() {
  group('HadithUrduDataSource', () {
    test('reads the text from the per-hadith Urdu file', () async {
      final adapter = _Adapter((_) => _ok('  $_urdu  '));
      expect(await _source(adapter).fetch('bukhari', 1), _urdu);
      expect(
        adapter.requests.single.toString(),
        endsWith('/editions/urd-bukhari/1.json'),
      );
    });

    test('a missing file (403/404) means "none", not a failure', () async {
      for (final status in [403, 404]) {
        final adapter = _Adapter((_) => _json({'error': 'x'}, status));
        expect(await _source(adapter).fetch('bukhari', 3000), '');
      }
    });

    test('an empty or odd body means "none"', () async {
      expect(await _source(_Adapter((_) => _ok('   '))).fetch('muslim', 1), '');
      expect(
        await _source(
          _Adapter((_) => _json({'hadiths': []})),
        ).fetch('muslim', 1),
        '',
      );
      expect(
        await _source(_Adapter((_) => _json([1, 2]))).fetch('muslim', 1),
        '',
      );
    });

    test('a server error or network failure is "unknown" (null)', () async {
      expect(
        await _source(_Adapter((_) => _json({}, 503))).fetch('bukhari', 1),
        isNull,
      );
      expect(
        await _source(
          _Adapter((o) => throw DioException(requestOptions: o)),
        ).fetch('bukhari', 1),
        isNull,
      );
    });
  });

  group('hadithUrduProvider', () {
    late FakeStorage storage;

    ProviderContainer make(_Adapter adapter) {
      final c = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          hadithUrduDataSourceProvider.overrideWithValue(_source(adapter)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => storage = FakeStorage());

    test('fetches once, then reads it from the saved copy', () async {
      final adapter = _Adapter((_) => _ok(_urdu));
      final key = urduKeyOf(_hadith());

      final first = make(adapter);
      expect(await first.read(hadithUrduProvider(key).future), _urdu);
      expect(adapter.requests, hasLength(1));

      // A new session (new container, same storage): no second request.
      final second = make(adapter);
      expect(await second.read(hadithUrduProvider(key).future), _urdu);
      expect(adapter.requests, hasLength(1));
    });

    test('a confirmed "none" is remembered', () async {
      final adapter = _Adapter((_) => _json({}, 404));
      final key = urduKeyOf(_hadith());
      expect(await make(adapter).read(hadithUrduProvider(key).future), '');
      expect(await make(adapter).read(hadithUrduProvider(key).future), '');
      expect(adapter.requests, hasLength(1));
    });

    test(
      'a failed request is an error (not "none") and is not remembered',
      () async {
        var fail = true;
        final adapter = _Adapter((_) => fail ? _json({}, 503) : _ok(_urdu));
        final key = urduKeyOf(_hadith());

        await expectLater(
          make(adapter).read(hadithUrduProvider(key).future),
          throwsA(isA<HadithUrduLoadFailure>()),
        );
        fail = false;
        expect(await make(adapter).read(hadithUrduProvider(key).future), _urdu);
        expect(adapter.requests, hasLength(2));
      },
    );

    test('collections with no Urdu edition never make a request', () async {
      final adapter = _Adapter((_) => _ok(_urdu));
      final h = _hadith(id: 'nawawi-5', collection: 'nawawi');
      expect(hasUrduEdition(h), isFalse);
      expect(
        await make(adapter).read(hadithUrduProvider(urduKeyOf(h)).future),
        '',
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'sub-narrations (402.2) get no Urdu rather than a neighbour\'s',
      () async {
        final adapter = _Adapter((_) => _ok(_urdu));
        final h = _hadith(id: 'bukhari-402.2');
        expect(hasUrduEdition(h), isFalse);
        expect(
          await make(adapter).read(hadithUrduProvider(urduKeyOf(h)).future),
          '',
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test('is stored in the API cache box', () async {
      final adapter = _Adapter((_) => _ok(_urdu));
      await make(adapter).read(hadithUrduProvider(urduKeyOf(_hadith())).future);
      expect(
        storage.boxes[AppConstants.apiCacheBoxName]?.keys,
        contains('hadith_urdu_bukhari_1'),
      );
      expect(
        HiveCacheStore(storage)
            .read<String>('hadith_urdu_bukhari_1', (j) => j['text'] as String)!
            .data,
        _urdu,
      );
    });
  });

  group('Hadith.toShareText', () {
    test('uses the given translation instead of English', () {
      final text = _hadith().toShareText(translation: _urdu);
      expect(text, contains(_urdu));
      expect(text, isNot(contains('Deeds are judged')));
    });

    test('is unchanged without one', () {
      final text = _hadith().toShareText();
      expect(text, contains('Deeds are judged'));
    });
  });

  group('HadithReaderPage in Urdu', () {
    late FakeStorage storage;
    setUp(() => storage = FakeStorage());

    Future<void> pumpPage(
      WidgetTester tester,
      _Adapter adapter, {
      Hadith? hadith,
      TranslationLanguage language = TranslationLanguage.urdu,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            hadithUrduDataSourceProvider.overrideWithValue(_source(adapter)),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, child) => MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: HadithReaderPage(
                  hadith: hadith ?? _hadith(),
                  collection: null,
                  preferences: ReadingPreferences(
                    translationLanguage: language,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the Urdu, right-to-left, in Nastaliq', (tester) async {
      await pumpPage(tester, _Adapter((_) => _ok(_urdu)));

      final urdu = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .firstWhere((t) => t.data == _urdu);
      expect(urdu.textDirection, TextDirection.rtl);
      expect(urdu.textAlign, TextAlign.right);
      expect(urdu.style?.fontFamily, 'NotoNastaliqUrdu');
      expect(find.text('URDU TRANSLATION'), findsOneWidget);
      expect(find.textContaining('Deeds are judged'), findsNothing);
    });

    testWidgets('says so, and shows no English, when there is none', (
      tester,
    ) async {
      await pumpPage(tester, _Adapter((_) => _json({}, 404)));

      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.textContaining('Deeds are judged'), findsNothing);
    });

    testWidgets('when it cannot be loaded, says so and retries on tap', (
      tester,
    ) async {
      var fail = true;
      await pumpPage(
        tester,
        _Adapter((_) => fail ? _json({}, 503) : _ok(_urdu)),
      );
      expect(
        find.textContaining('Couldn’t load the Urdu translation'),
        findsOneWidget,
      );
      expect(find.textContaining('Deeds are judged'), findsNothing);

      fail = false;
      await tester.tap(find.textContaining('Couldn’t load'));
      await tester.pumpAndSettle();
      expect(find.text(_urdu), findsOneWidget);
    });

    testWidgets('English choice never touches the network', (tester) async {
      final adapter = _Adapter((_) => _ok(_urdu));
      await pumpPage(tester, adapter, language: TranslationLanguage.english);

      expect(adapter.requests, isEmpty);
      expect(find.textContaining('Deeds are judged'), findsOneWidget);
      expect(find.text(_urdu), findsNothing);
    });
  });
}
