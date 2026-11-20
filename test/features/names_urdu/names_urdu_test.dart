import 'dart:io';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/asma_ul_husna/domain/asma_urdu_texts.dart';
import 'package:deen_companion/features/asma_ul_husna/domain/entities/asma_daily.dart';
import 'package:deen_companion/features/asma_ul_husna/domain/entities/asma_name.dart';
import 'package:deen_companion/features/asma_ul_husna/domain/repositories/asma_ul_husna_repository.dart';
import 'package:deen_companion/features/asma_ul_husna/presentation/providers/asma_ul_husna_providers.dart';
import 'package:deen_companion/features/asma_ul_husna/presentation/providers/asma_urdu_providers.dart';
import 'package:deen_companion/features/asma_ul_husna/presentation/screens/asma_daily_practice_screen.dart';
import 'package:deen_companion/features/asma_ul_husna/presentation/screens/asma_detail_screen.dart';
import 'package:deen_companion/features/asma_ul_husna/presentation/widgets/asma_cards.dart';
import 'package:deen_companion/features/islamic_names/domain/entities/islamic_name.dart';
import 'package:deen_companion/features/islamic_names/domain/islamic_names_urdu_texts.dart';
import 'package:deen_companion/features/islamic_names/domain/services/islamic_names_filter.dart';
import 'package:deen_companion/features/islamic_names/presentation/providers/islamic_names_providers.dart';
import 'package:deen_companion/features/islamic_names/presentation/screens/islamic_name_detail_screen.dart';
import 'package:deen_companion/shared/domain/urdu_lookup.dart';
import 'package:deen_companion/shared/widgets/saved_localized_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/fake_storage.dart';

class _AsmaRepo extends Mock implements AsmaUlHusnaRepository {}

final _latin = RegExp('[A-Za-z]');

AsmaUrduTexts _asma() =>
    AsmaUrduTexts.parse(File('assets/data/asma_urdu.json').readAsStringSync());
IslamicNamesUrduTexts _names() => IslamicNamesUrduTexts.parse(
  File('assets/data/islamic_names_urdu.json').readAsStringSync(),
);

const _rahman = AsmaName(
  number: 1,
  arabic: 'الرَّحْمٰنُ',
  transliteration: 'Ar-Rahman',
  english: 'The Most Merciful',
  meaning: 'The One who has plenty of mercy for the believers.',
);
const _raheem = AsmaName(
  number: 2,
  arabic: 'الرَّحِيمُ',
  transliteration: 'Ar-Raheem',
  english: 'The Most Compassionate',
  meaning: 'The One who has plenty of mercy for the believers.',
);

const _muhammad = IslamicName(
  id: 1,
  name: 'Muhammad',
  arabic: 'مُحَمَّد',
  gender: 'male',
  meaning: 'Praised, commendable',
  origin: 'Arabic',
  root: 'ح م د',
  note: 'The name of the Final Prophet (ﷺ).',
);
const _noNote = IslamicName(
  id: 2,
  name: 'Ahmad',
  arabic: 'أَحْمَد',
  gender: 'male',
  meaning: 'Most praised',
  origin: 'Arabic',
  note: '',
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String language = 'urdu',
  List<Override> overrides = const [],
}) async {
  final storage = FakeStorage()
    ..boxes[AppConstants.settingsBoxName] = {
      'reader_translation_language': language,
    };
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        asmaUrduTextsProvider.overrideWith((_) async => _asma()),
        islamicNamesUrduTextsProvider.overrideWith((_) async => _names()),
        ...overrides,
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => home)],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the bundled Urdu', () {
    final asma = _asma();
    final names = _names();

    test('has every one of the 99 Names, all Urdu', () {
      for (var n = 1; n <= 99; n++) {
        expect(asma.epithetOf(n), isNotNull, reason: 'epithet $n');
        expect(asma.meaningOf(n), isNotNull, reason: 'meaning $n');
        final both = '${asma.epithetOf(n)} ${asma.meaningOf(n)}';
        expect(_latin.hasMatch(both), isFalse, reason: 'name $n: $both');
      }
    });

    test('has every one of the 210 Islamic names, all Urdu', () {
      for (var id = 1; id <= 210; id++) {
        expect(names.nameOf(id), isNotNull, reason: 'name $id');
        expect(names.meaningOf(id), isNotNull, reason: 'meaning $id');
        expect(names.noteOf(id), isNotNull, reason: 'note $id');
        final all =
            '${names.nameOf(id)} ${names.meaningOf(id)} ${names.noteOf(id)}';
        expect(_latin.hasMatch(all), isFalse, reason: 'name $id: $all');
      }
    });

    test('has every origin the source uses', () {
      for (final o in [
        'Arabic',
        'Hebrew/Arabic',
        'Persian/Arabic',
        'Aramaic/Arabic',
        'Arabic/Urdu',
        'Arabic/Persian',
        'Arabic/Hebrew',
      ]) {
        expect(names.originOf(o), isNotNull, reason: o);
        expect(_latin.hasMatch(names.originOf(o)!), isFalse, reason: o);
      }
    });
  });

  group('AsmaUrduTexts', () {
    test('Urdu epithet and meaning; the English kept for saving', () {
      final n = _asma().name(_rahman);
      expect(n.urdu, isTrue);
      expect(n.english, 'نہایت مہربان');
      expect(n.meaning, contains('وہ ذات'));
      expect(n.englishEpithet, 'The Most Merciful');
      expect(n.englishMeaning, _rahman.meaning);
      // The Arabic and the transliteration are untouched.
      expect(n.arabic, _rahman.arabic);
      expect(n.transliteration, 'Ar-Rahman');
    });

    test('no Urdu: no meaning, never the English', () {
      final n = AsmaUrduTexts.empty.name(_rahman);
      expect(n.meaning, isEmpty);
      expect(n.urdu, isTrue);
    });

    test('a day in Urdu: weekday, notes and Names', () {
      final d = _asma().daily(
        const AsmaDaily(
          dayNumber: 5,
          dayName: 'Friday',
          names: [_rahman],
          count: 1,
          suggestion: 'Recite',
          weeklyCompletion: 'Complete all 99 names',
        ),
      );
      expect(d.dayName, 'جمعہ');
      expect(d.weeklyCompletion, contains('99'));
      expect(_latin.hasMatch(d.weeklyCompletion), isFalse);
      expect(d.names.single.urdu, isTrue);
    });

    test('search finds by a word of the Urdu epithet or meaning', () {
      final found = _asma().search('رحم');
      expect(found, containsAll([1, 2]));
      expect(_asma().search('   '), isEmpty);
    });
  });

  group('IslamicNamesUrduTexts', () {
    test('the Urdu name, meaning, origin and note', () {
      final n = _names().name(_muhammad);
      expect(n.urdu, isTrue);
      expect(n.name, 'محمد');
      expect(n.meaning, 'قابلِ تعریف، ستودہ');
      expect(n.origin, 'عربی');
      expect(n.note, contains('آخری نبی'));
      expect(n.englishName, 'Muhammad');
      expect(n.englishOrigin, 'Arabic');
      expect(n.arabic, _muhammad.arabic);
    });

    test('a name with no note needs none in Urdu', () {
      final n = _names().name(_noNote);
      expect(n.hasNote, isFalse);
    });

    test('no Urdu: no meaning or note, never the English', () {
      final n = IslamicNamesUrduTexts.empty.name(_muhammad);
      expect(n.meaning, isEmpty);
      expect(n.note, isEmpty);
      expect(n.hasNote, isTrue); // there is a note; there is just no Urdu
    });
  });

  group('IslamicNamesFilter in Urdu', () {
    final urdu = _names().names([_muhammad, _noNote]);

    test('finds by the Urdu name, with or without marks', () {
      expect(IslamicNamesFilter.apply(urdu, query: 'محمد'), [urdu.first]);
      expect(IslamicNamesFilter.apply(urdu, query: 'مُحَمَّد'), [urdu.first]);
    });

    test('still finds by the English, whatever is shown', () {
      expect(IslamicNamesFilter.apply(urdu, query: 'ahmad'), [urdu.last]);
      expect(IslamicNamesFilter.apply(urdu, query: 'praised'), isNotEmpty);
    });

    test('the origin filter works on the English origin', () {
      expect(IslamicNamesFilter.uniqueOrigins(urdu), ['Arabic']);
      expect(
        IslamicNamesFilter.apply(urdu, originFilters: {'Arabic'}),
        hasLength(2),
      );
      expect(
        IslamicNamesFilter.apply(urdu, originFilters: {'Persian'}),
        isEmpty,
      );
    });

    test('groups by the Urdu alphabet, in its own order', () {
      final list = _names().names([
        const IslamicName(
          id: 100,
          name: 'Zayd',
          arabic: '',
          gender: 'male',
          meaning: '',
          origin: 'Arabic',
          note: '',
        ),
        _muhammad,
        _noNote,
      ]);
      // احمد (ا) comes before محمد (م) and زید (ز).
      final keys = IslamicNamesFilter.groupAlphabetically(list).keys.toList();
      expect(keys.first, 'ا');
    });
  });

  group('saved rows', () {
    Widget row(UrduLookup l, {bool title = false}) => SavedLocalizedText(
      text: 'Saved English',
      isTitle: title,
      style: const TextStyle(fontSize: 12),
      lookup: Provider((_) => l),
    );

    testWidgets('English: the saved text', (tester) async {
      await _pump(tester, Scaffold(body: row(UrduLookup.notUrdu)));
      expect(find.text('Saved English'), findsOneWidget);
    });

    testWidgets('Urdu found: the Urdu, not the saved English', (tester) async {
      await _pump(tester, Scaffold(body: row(const UrduLookup.found('اردو'))));
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('Saved English'), findsNothing);
    });

    testWidgets('Urdu missing: says so, not the English', (tester) async {
      await _pump(tester, Scaffold(body: row(UrduLookup.missing)));
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text('Saved English'), findsNothing);
    });

    testWidgets('a title with no Urdu keeps its saved text', (tester) async {
      await _pump(tester, Scaffold(body: row(UrduLookup.missing, title: true)));
      expect(find.text('Saved English'), findsOneWidget);
    });
  });

  group('providers', () {
    late _AsmaRepo repo;
    setUp(() {
      repo = _AsmaRepo();
      when(() => repo.getCachedAllNames()).thenReturn(null);
      when(
        () => repo.fetchAndCacheAllNames(),
      ).thenAnswer((_) async => const Success([_rahman, _raheem]));
    });

    ProviderContainer container(String language) {
      final c = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            FakeStorage()
              ..boxes[AppConstants.settingsBoxName] = {
                'reader_translation_language': language,
              },
          ),
          asmaRepositoryProvider.overrideWithValue(repo),
          asmaUrduTextsProvider.overrideWith((_) async => _asma()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('English: the Names as the source has them', () async {
      final c = container('english');
      await c.read(asmaAllNamesNotifierProvider.future);
      final names = c.read(localizedAsmaNamesProvider).value!;
      expect(names.first.english, 'The Most Merciful');
      expect(names.first.urdu, isFalse);
    });

    test('Urdu: the Names in Urdu', () async {
      final c = container('urdu');
      await c.read(asmaAllNamesNotifierProvider.future);
      await c.read(asmaUrduTextsProvider.future);
      final names = c.read(localizedAsmaNamesProvider).value!;
      expect(names.first.english, 'نہایت مہربان');
      expect(names.first.urdu, isTrue);
    });

    test('typing Urdu searches the bundled Urdu, not the source', () async {
      final c = container('english');
      await c.read(asmaSearchNotifierProvider.notifier).search('رحم');
      final found = c.read(asmaSearchNotifierProvider).value!;
      expect(found.map((n) => n.number), containsAll([1, 2]));
      verifyNever(() => repo.search(any()));
    });
  });

  group('the Names of Allah screens', () {
    testWidgets('card in English: as the source has it', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: AsmaNameCard(name: _rahman)),
        language: 'english',
      );
      expect(find.text('The Most Merciful'), findsOneWidget);
      expect(find.text(_rahman.meaning), findsOneWidget);
    });

    testWidgets('card in Urdu: Urdu epithet and meaning, no English', (
      tester,
    ) async {
      final urdu = _asma().name(_rahman);
      await _pump(tester, Scaffold(body: AsmaNameCard(name: urdu)));
      expect(find.text('نہایت مہربان'), findsOneWidget);
      expect(find.text(urdu.meaning), findsOneWidget);
      expect(find.text('The Most Merciful'), findsNothing);
      expect(find.text(_rahman.meaning), findsNothing);
      // The Arabic and transliteration stay.
      expect(find.text(_rahman.arabic), findsOneWidget);
      expect(find.text('Ar-Rahman'), findsOneWidget);
    });

    testWidgets('card in Urdu with no Urdu meaning says so', (tester) async {
      await _pump(
        tester,
        Scaffold(body: AsmaNameCard(name: AsmaUrduTexts.empty.name(_rahman))),
      );
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_rahman.meaning), findsNothing);
    });

    testWidgets('detail: hero, card, tasbih and controls; counting works', (
      tester,
    ) async {
      await _pump(
        tester,
        AsmaDetailScreen(
          names: [_asma().name(_rahman), _asma().name(_raheem)],
          initialIndex: 0,
        ),
      );
      expect(find.text('Names of Allah'), findsOneWidget);
      expect(find.text('Name 1 of 99'), findsOneWidget);
      expect(find.text('Tap to recite'), findsOneWidget);
      expect(find.text('  of 2'), findsOneWidget);

      await tester.tap(find.text('0'));
      await tester.pump();
      expect(find.text('1 of 33'), findsOneWidget);

      // Next goes to the second Name.
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Ar-Raheem'), findsOneWidget);
      expect(find.text('Name 2 of 99'), findsOneWidget);
    });

    testWidgets('daily practice: Urdu day, Names, recite and finish', (
      tester,
    ) async {
      final repo = _AsmaRepo();
      when(() => repo.fetchDailyNames(any())).thenAnswer(
        (_) async => const Success(
          AsmaDaily(
            dayNumber: 1,
            dayName: 'Monday',
            names: [_rahman],
            count: 1,
            suggestion: 'Recite',
            weeklyCompletion: 'Complete all 99 names',
          ),
        ),
      );
      await _pump(
        tester,
        const AsmaDailyPracticeScreen(initialDay: 1),
        overrides: [asmaRepositoryProvider.overrideWithValue(repo)],
      );
      expect(find.text('DAILY DHIKR'), findsOneWidget);
      expect(find.text('پیر'), findsWidgets); // Monday, in Urdu
      expect(find.text('Monday'), findsNothing);
      expect(find.text('نہایت مہربان'), findsOneWidget);
      expect(find.text('The Most Merciful'), findsNothing);

      // Recite the target (3 by default), then Finish.
      for (var i = 0; i < 3; i++) {
        // Tapping the Name (the dial) counts a recitation.
        await tester.tap(find.text(_rahman.arabic));
        await tester.pump();
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Dhikr complete'), findsOneWidget);
      expect(find.textContaining('تمام 99'), findsOneWidget);
    });
  });

  group('Islamic name detail', () {
    testWidgets('Urdu: the Urdu name, meaning and note, no English', (
      tester,
    ) async {
      final n = _names().name(_muhammad);
      await _pump(tester, IslamicNameDetailScreen(name: n, pool: [n]));
      expect(find.text('محمد'), findsWidgets);
      expect(find.text('Muhammad'), findsNothing);
      expect(find.text('قابلِ تعریف، ستودہ'), findsWidgets);
      expect(find.textContaining('آخری نبی'), findsOneWidget);
      expect(find.text('Praised, commendable'), findsNothing);
      // The Arabic is untouched.
      expect(find.text('مُحَمَّد'), findsWidgets);
    });

    testWidgets('Urdu with no Urdu text says so, not English', (tester) async {
      final n = IslamicNamesUrduTexts.empty.name(_muhammad);
      await _pump(tester, IslamicNameDetailScreen(name: n, pool: [n]));
      expect(find.text('Urdu translation is not available'), findsNWidgets(2));
      expect(find.textContaining('Final Prophet'), findsNothing);
    });

    testWidgets('English: unchanged', (tester) async {
      await _pump(
        tester,
        const IslamicNameDetailScreen(name: _muhammad, pool: [_muhammad]),
        language: 'english',
      );
      expect(find.text('Muhammad'), findsWidgets);
      expect(find.text('Praised, commendable'), findsWidgets);
    });
  });

  test('network failure type is still a Failure', () {
    expect(const NetworkFailure(), isA<Failure>());
  });
}
