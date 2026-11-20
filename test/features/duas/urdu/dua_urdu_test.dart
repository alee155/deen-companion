import 'dart:io';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/duas/domain/dua_urdu_texts.dart';
import 'package:deen_companion/features/duas/domain/entities/dua.dart';
import 'package:deen_companion/features/duas/domain/entities/dua_category.dart';
import 'package:deen_companion/features/duas/domain/entities/duas_bundle.dart';
import 'package:deen_companion/features/duas/domain/repositories/dua_repository.dart';
import 'package:deen_companion/features/duas/presentation/providers/dua_providers.dart';
import 'package:deen_companion/features/duas/presentation/providers/dua_urdu_providers.dart';
import 'package:deen_companion/features/duas/presentation/widgets/dua_common.dart';
import 'package:deen_companion/features/duas/presentation/widgets/saved_dua_text.dart';
import 'package:deen_companion/features/favorites/domain/entities/favorite_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/fake_storage.dart';

class _Repo extends Mock implements DuaRepository {}

const _en = 'O Allah, open for me the doors of Your mercy.';
const _enTitle = 'Entering the Masjid';

Dua _dua({int id = 23}) => Dua(
  id: id,
  category: 'masjid',
  title: _enTitle,
  arabic: 'اللهم افتح لي أبواب رحمتك',
  transliteration: 'Allahumma iftah li abwaba rahmatik',
  translation: _en,
  source: 'Sahih Muslim 1:494',
  repeat: 1,
);

DuaUrduTexts _real() =>
    DuaUrduTexts.parse(File('assets/data/duas_urdu.json').readAsStringSync());

final _latin = RegExp('[A-Za-z]');

void main() {
  group('the bundled Urdu', () {
    final json = File('assets/data/duas_urdu.json').readAsStringSync();
    final texts = DuaUrduTexts.parse(json);

    test('has every dua the source has (ids 1 to 127)', () {
      for (var id = 1; id <= 127; id++) {
        expect(texts.titleOf(id), isNotNull, reason: 'title of dua $id');
        expect(
          texts.hasTranslation(id),
          isTrue,
          reason: 'translation of dua $id',
        );
      }
    });

    test('has every category', () {
      const ids = [
        'morning', 'evening', 'wudu', 'prayer', 'after_prayer', 'sleep', //
        'food', 'travel', 'home', 'masjid', 'distress', 'forgiveness',
        'illness', 'weather', 'knowledge', 'parents', 'guidance', 'gratitude',
        'protection', 'dhikr', 'marriage', 'hajj', 'grief', 'children',
        'business', 'night_prayer', 'quran_recitation',
      ];
      for (final id in ids) {
        final c = texts.category(
          DuaCategory(id: id, name: 'EN', description: 'EN', count: 1),
        );
        expect(c.name, isNot('EN'), reason: '$id name');
        expect(c.description, isNot('EN'), reason: '$id description');
        expect(c.urdu, isTrue);
        expect(c.englishName, 'EN');
      }
    });

    test('is all Urdu: no English letters left in any text', () {
      for (var id = 1; id <= 127; id++) {
        final both = '${texts.titleOf(id)} ${texts.translationOf(id)}';
        expect(
          _latin.hasMatch(both),
          isFalse,
          reason: 'dua $id: ${_latin.allMatches(both).map((m) => m[0]).join()}',
        );
      }
    });

    test('the long Quran passages are the Quran Urdu in full', () {
      // Ayat al-Kursi, the last two verses of al-Baqarah, al-Fatiha.
      expect(texts.translationOf(13)!, contains('وہ زندہ جاوید ہستی'));
      expect(
        texts.translationOf(92)!,
        contains('رسُول اُس ہدایت پر ایمان لایا'),
      );
      expect(texts.translationOf(125)!, contains('روزِ جزا کا مالک ہے'));
    });
  });

  group('DuaUrduTexts.dua', () {
    test('takes the Urdu and keeps the English for saving', () {
      final d = _real().dua(_dua());
      expect(d.urdu, isTrue);
      expect(d.title, 'مسجد میں داخل ہوتے وقت');
      expect(d.translation, contains('رحمت کے دروازے'));
      expect(d.englishTitle, _enTitle);
      expect(d.englishTranslation, _en);
      // The Arabic is untouched.
      expect(d.arabic, _dua().arabic);
    });

    test('a dua with no Urdu has no translation: never the English', () {
      final d = DuaUrduTexts.empty.dua(_dua());
      expect(d.urdu, isTrue);
      expect(d.translation, isEmpty);
      expect(d.title, _enTitle); // a name; nothing else to show
    });
  });

  group('search in Urdu', () {
    final texts = _real();
    final categoryOf = {for (var i = 1; i <= 127; i++) i: 'x'};

    test('finds by a word in the title', () {
      final ids = texts.search('مسجد', categoryOf: categoryOf);
      expect(ids, containsAll([23, 24]));
    });

    test('finds by a word in the translation', () {
      expect(
        texts.search('رحمت کے دروازے', categoryOf: categoryOf),
        contains(23),
      );
    });

    test('every word has to match', () {
      expect(texts.search('مسجد زکوۃ', categoryOf: categoryOf), isEmpty);
    });

    test('title matches come before translation-only matches', () {
      final ids = texts.search('بارش', categoryOf: categoryOf);
      expect(ids.first, anyOf(32, 33)); // titled "when it rains / after rain"
    });

    test('spelling variants are one word', () {
      // ك/ک, ي/ی, with or without marks.
      expect(DuaUrduTexts.normalize('كِتاب'), DuaUrduTexts.normalize('کتاب'));
      expect(DuaUrduTexts.normalize('دعائ'), DuaUrduTexts.normalize('دعای'));
    });

    test('nothing for an empty query', () {
      expect(texts.search('  ', categoryOf: categoryOf), isEmpty);
    });
  });

  group('providers', () {
    late _Repo repo;

    setUp(() {
      repo = _Repo();
      when(() => repo.getCachedBundle()).thenReturn(null);
      when(() => repo.fetchAndCacheBundle()).thenAnswer(
        (_) async => Success(
          DuasBundle(
            categories: const [
              DuaCategory(
                id: 'masjid',
                name: 'Masjid',
                description: 'Entering and leaving the mosque',
                count: 2,
              ),
            ],
            duas: [_dua(), _dua(id: 24)],
          ),
        ),
      );
    });

    ProviderContainer container(String language) {
      final storage = FakeStorage()
        ..boxes[AppConstants.settingsBoxName] = {
          'reader_translation_language': language,
        };
      final c = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          duaRepositoryProvider.overrideWithValue(repo),
          duaUrduTextsProvider.overrideWith((_) async => _real()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('English: the bundle exactly as the source has it', () async {
      final c = container('english');
      await c.read(duasBundleNotifierProvider.future);
      final b = c.read(localizedDuasBundleProvider).value!;
      expect(b.duas.first.title, _enTitle);
      expect(b.duas.first.urdu, isFalse);
      expect(b.categories.single.name, 'Masjid');
    });

    test('Urdu: titles, translations and category names are Urdu', () async {
      final c = container('urdu');
      await c.read(duasBundleNotifierProvider.future);
      await c.read(duaUrduTextsProvider.future);
      final b = c.read(localizedDuasBundleProvider).value!;
      expect(b.duas.first.title, 'مسجد میں داخل ہوتے وقت');
      expect(b.duas.first.translation, isNot(_en));
      expect(b.categories.single.name, 'مسجد');
      expect(b.categories.single.englishName, 'Masjid');
      // Same ids, same grouping.
      expect(b.byCategory('masjid').map((d) => d.id), [23, 24]);
    });

    test('Urdu typed: searches the bundled Urdu, in either language', () async {
      for (final language in ['english', 'urdu']) {
        final c = container(language);
        await c.read(duaSearchNotifierProvider.notifier).search('مسجد');
        final found = c.read(duaSearchNotifierProvider).value!;
        expect(found.map((d) => d.id), containsAll([23, 24]), reason: language);
        // The source's English search is not asked for Urdu words.
        verifyNever(() => repo.search(any()));
      }
    });

    test(
      'English typed: the source searches, shown in Urdu if chosen',
      () async {
        when(
          () => repo.search('mosque'),
        ).thenAnswer((_) async => Success([_dua()]));
        final c = container('urdu');
        await c.read(duaUrduTextsProvider.future);
        await c.read(duaSearchNotifierProvider.notifier).search('mosque');
        final shown = c.read(localizedDuaSearchProvider).value!;
        expect(shown.single.urdu, isTrue);
        expect(shown.single.title, 'مسجد میں داخل ہوتے وقت');
      },
    );
  });

  group('saving', () {
    test('Favorites keep the English, whatever is shown', () {
      final urdu = _real().dua(_dua());
      final item = duaFavoriteItem(urdu);
      expect(item.title, _enTitle);
      expect(item.subtitle, _en);
      expect(item.type, FavoriteContentType.dua);
    });

    test('a category looks the same in every language', () {
      const english = DuaCategory(
        id: 'morning',
        name: 'Morning Adhkar',
        description: '',
        count: 1,
      );
      final urdu = _real().category(english);
      final a = DuaCategoryStyle.of(english);
      final b = DuaCategoryStyle.of(urdu);
      expect(b.icon, a.icon);
      expect(b.accent, a.accent);
    });
  });

  group('on screen', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      String language = 'urdu',
      DuaUrduTexts? texts,
    }) async {
      final storage = FakeStorage()
        ..boxes[AppConstants.settingsBoxName] = {
          'reader_translation_language': language,
        };
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            duaUrduTextsProvider.overrideWith((_) async => texts ?? _real()),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(body: SingleChildScrollView(child: child)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Widget card(Dua d) => DuaPreviewCard(
      dua: d,
      number: 1,
      accent: Colors.green,
      bg: Colors.green.shade50,
      onTap: () {},
    );

    testWidgets('English card: the English, as before', (tester) async {
      await pump(tester, card(_dua()), language: 'english');
      expect(find.text(_enTitle), findsOneWidget);
      expect(find.text(_en), findsOneWidget);
    });

    testWidgets('Urdu card: the Urdu title and translation, not the English', (
      tester,
    ) async {
      final urdu = _real().dua(_dua());
      await pump(tester, card(urdu));
      expect(find.text('مسجد میں داخل ہوتے وقت'), findsOneWidget);
      expect(find.text(urdu.translation), findsOneWidget);
      expect(find.text(_en), findsNothing);
      expect(find.text(_enTitle), findsNothing);
      // The Arabic stays.
      expect(find.text(_dua().arabic), findsOneWidget);
    });

    testWidgets('Urdu card with no Urdu translation says so, not English', (
      tester,
    ) async {
      await pump(tester, card(DuaUrduTexts.empty.dua(_dua())));
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_en), findsNothing);
    });

    testWidgets('a saved dua row follows the language, from its id', (
      tester,
    ) async {
      const row = Column(
        children: [
          SavedDuaTitle(
            duaId: '23',
            text: _enTitle,
            style: TextStyle(fontSize: 14),
          ),
          SavedDuaPreview(
            duaId: '23',
            text: _en,
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
      await pump(tester, row);
      expect(find.text('مسجد میں داخل ہوتے وقت'), findsOneWidget);
      expect(find.text(_enTitle), findsNothing);
      expect(find.text(_en), findsNothing);
    });

    testWidgets('a saved dua row in English is the saved text', (tester) async {
      const row = Column(
        children: [
          SavedDuaTitle(
            duaId: '23',
            text: _enTitle,
            style: TextStyle(fontSize: 14),
          ),
          SavedDuaPreview(
            duaId: '23',
            text: _en,
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
      await pump(tester, row, language: 'english');
      expect(find.text(_enTitle), findsOneWidget);
      expect(find.text(_en), findsOneWidget);
    });

    testWidgets('a saved dua with no Urdu says so, not English', (
      tester,
    ) async {
      const row = SavedDuaPreview(
        duaId: '23',
        text: _en,
        style: TextStyle(fontSize: 12),
      );
      await pump(tester, row, texts: DuaUrduTexts.empty);
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_en), findsNothing);
    });
  });
}
