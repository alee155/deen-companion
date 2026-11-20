import 'dart:async';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/features/daily_content/presentation/widgets/daily_reading_section.dart';
import 'package:deen_companion/shared/domain/explore_icon_assets.dart';
import 'package:deen_companion/features/hadith/data/datasources/hadith_urdu_datasource.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/features/hadith/presentation/providers/hadith_urdu_providers.dart';
import 'package:deen_companion/features/hadith/presentation/widgets/hadith_card_tile.dart';
import 'package:deen_companion/features/hadith/presentation/widgets/hadith_preview_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/fake_storage.dart';

const _en = 'Narrated Umar: Deeds are judged by intentions.';
const _ur = 'اعمال کا دارومدار نیتوں پر ہے';

Hadith _h({String id = 'bukhari-1', String collection = 'bukhari'}) => Hadith(
  id: id,
  collection: collection,
  collectionName: 'Sahih al-Bukhari',
  hadithNumber: 1,
  arabic: 'ar',
  english: _en,
  grade: 'Sahih',
);

class _Source implements HadithUrduDataSource {
  final Future<String?> Function() handler;
  final calls = <String>[];
  _Source(this.handler);
  @override
  Future<String?> fetch(String collection, int number) {
    calls.add('$collection/$number');
    return handler();
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required _Source source,
  required String language,
}) async {
  final storage = FakeStorage()
    ..boxes[AppConstants.settingsBoxName] = {
      'reader_translation_language': language,
    };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        hadithUrduDataSourceProvider.overrideWithValue(source),
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

void main() {
  group('hadithCollectionOfId', () {
    test('reads the collection key', () {
      expect(hadithCollectionOfId('bukhari-1'), 'bukhari');
      expect(hadithCollectionOfId('ibnmajah-402'), 'ibnmajah');
    });
    test('not a hadith id', () {
      for (final bad in ['bukhari', '', '-1', 'bukhari-']) {
        expect(hadithCollectionOfId(bad), isNull, reason: bad);
      }
    });
  });

  group('HadithPreviewText (Favorites / Recent)', () {
    Widget preview({String? id = 'bukhari-1'}) =>
        HadithPreviewText(text: _en, hadithId: id);

    testWidgets('English chosen: the saved snippet, no request', (
      tester,
    ) async {
      final source = _Source(() async => _ur);
      await _pump(tester, preview(), source: source, language: 'english');
      expect(find.text(_en), findsOneWidget);
      expect(source.calls, isEmpty);
    });

    testWidgets('Urdu chosen: the Urdu, right-to-left', (tester) async {
      final source = _Source(() async => _ur);
      await _pump(tester, preview(), source: source, language: 'urdu');
      final t = tester.widget<Text>(find.text(_ur));
      expect(t.textDirection, TextDirection.rtl);
      expect(t.style?.fontFamily, 'NotoNastaliqUrdu');
      expect(find.text(_en), findsNothing);
    });

    testWidgets('Urdu chosen, loading: nothing drawn, never the English', (
      tester,
    ) async {
      final gate = Completer<String?>();
      final source = _Source(() => gate.future);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              FakeStorage()
                ..boxes[AppConstants.settingsBoxName] = {
                  'reader_translation_language': 'urdu',
                },
            ),
            hadithUrduDataSourceProvider.overrideWithValue(source),
          ],
          child: MaterialApp(home: Scaffold(body: preview())),
        ),
      );
      await tester.pump();
      expect(find.text(_en), findsNothing);
      gate.complete(_ur);
      await tester.pumpAndSettle();
      expect(find.text(_ur), findsOneWidget);
    });

    testWidgets('a row that is not one hadith keeps its text', (tester) async {
      final source = _Source(() async => _ur);
      await _pump(tester, preview(id: null), source: source, language: 'urdu');
      expect(find.text(_en), findsOneWidget);
      // A "Reading" entry stores only the collection key, not a hadith id.
      await _pump(
        tester,
        preview(id: 'bukhari'),
        source: source,
        language: 'urdu',
      );
      expect(find.text(_en), findsOneWidget);
      expect(source.calls, isEmpty);
    });

    testWidgets('a collection with no Urdu says so, no English', (
      tester,
    ) async {
      final source = _Source(() async => _ur);
      await _pump(
        tester,
        preview(id: 'nawawi-5'),
        source: source,
        language: 'urdu',
      );
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_en), findsNothing);
      expect(source.calls, isEmpty);
    });

    testWidgets('Urdu chosen but not there: says so, no English', (
      tester,
    ) async {
      final source = _Source(() async => '');
      await _pump(tester, preview(), source: source, language: 'urdu');
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_en), findsNothing);
    });
  });

  group('HadithCardTile (hadith search results)', () {
    testWidgets('English: unchanged', (tester) async {
      final source = _Source(() async => _ur);
      await _pump(
        tester,
        HadithCardTile(hadith: _h(), onTap: () {}),
        source: source,
        language: 'english',
      );
      expect(find.text(_en), findsOneWidget);
      expect(source.calls, isEmpty);
    });

    testWidgets('Urdu: shows the Urdu preview instead', (tester) async {
      final source = _Source(() async => _ur);
      await _pump(
        tester,
        HadithCardTile(hadith: _h(), onTap: () {}),
        source: source,
        language: 'urdu',
      );
      expect(find.text(_ur), findsOneWidget);
      expect(find.text(_en), findsNothing);
    });

    testWidgets('Urdu, collection without an Urdu edition: says so', (
      tester,
    ) async {
      final source = _Source(() async => _ur);
      await _pump(
        tester,
        HadithCardTile(
          hadith: _h(id: 'nawawi-5', collection: 'nawawi'),
          onTap: () {},
        ),
        source: source,
        language: 'urdu',
      );
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_en), findsNothing);
      expect(source.calls, isEmpty);
    });
  });

  group('DailyReadingSection', () {
    Widget section({
      String translation = _en,
      bool urdu = false,
      bool loading = false,
      String? note,
    }) => SingleChildScrollView(
      child: DailyReadingSection(
        iconAsset: exploreIconAssets['quran']!,
        title: 'Ayat of the Day',
        source: 'src',
        arabic: 'ar',
        translation: translation,
        translationIsUrdu: urdu,
        translationStyle: const TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        translationLoading: loading,
        note: note,
        onShare: () {},
      ),
    );

    Future<void> pumpSection(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: child),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('English is laid out as before (left-to-right)', (
      tester,
    ) async {
      await pumpSection(tester, section());
      final t = tester.widget<Text>(find.text(_en));
      expect(t.textDirection, isNull);
      expect(t.style?.fontFamily, isNot('NotoNastaliqUrdu'));
    });

    testWidgets('Urdu is right-to-left in Nastaliq', (tester) async {
      await pumpSection(tester, section(translation: _ur, urdu: true));
      final t = tester.widget<Text>(find.text(_ur));
      expect(t.textDirection, TextDirection.rtl);
      expect(t.textAlign, TextAlign.right);
      expect(t.style?.fontFamily, 'NotoNastaliqUrdu');
    });

    testWidgets('loading shows a spinner and no text', (tester) async {
      await pumpSection(tester, section(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_en), findsNothing);
    });

    testWidgets('a note is shown above the translation', (tester) async {
      await pumpSection(tester, section(note: 'No Urdu for this one.'));
      expect(find.text('No Urdu for this one.'), findsOneWidget);
      expect(find.text(_en), findsOneWidget);
    });
  });
}
