import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/features/hadith/domain/repositories/hadith_repository.dart';
import 'package:deen_companion/features/hadith/presentation/providers/hadith_providers.dart';
import 'package:deen_companion/features/hadith/presentation/screens/hadith_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/fake_storage.dart';

class _Repo extends Mock implements HadithRepository {}

Hadith _h(String collection, int n, String english) => Hadith(
  id: '$collection-$n',
  collection: collection,
  collectionName: collection,
  hadithNumber: n,
  arabic: 'ar',
  english: english,
  grade: 'Sahih',
);

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    when(() => repo.getCachedCollections()).thenReturn(null);
    when(
      () => repo.fetchAndCacheCollections(),
    ).thenAnswer((_) async => const Error(NetworkFailure()));
  });

  void stubSearch(List<Hadith> Function(String term, String? collection) hits) {
    when(
      () => repo.search(
        any(),
        collection: any(named: 'collection'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (i) async => Success(
        hits(
          i.positionalArguments.first as String,
          i.namedArguments[#collection] as String?,
        ),
      ),
    );
    when(
      () => repo.search(any(), collection: any(named: 'collection')),
    ).thenAnswer(
      (i) async => Success(
        hits(
          i.positionalArguments.first as String,
          i.namedArguments[#collection] as String?,
        ),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    String language = 'english',
    String? collection,
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
          hadithRepositoryProvider.overrideWithValue(repo),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light(),
            // The app bar's back button needs a router to ask.
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      HadithSearchScreen(currentCollection: collection),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder field() => find.byType(TextField);

  group('before searching', () {
    testWidgets('says what to search for and how', (tester) async {
      await pump(tester);

      // The hint names an example.
      expect(
        tester.widget<TextField>(field()).decoration!.hintText,
        'Search by word, e.g. fasting',
      );
      expect(find.text('Find a hadith'), findsOneWidget);
      expect(
        find.textContaining('reads the English translation'),
        findsOneWidget,
      );
      // Suggestions: topics and narrators.
      for (final topic in ['Prayer', 'Fasting', 'Charity', 'Patience']) {
        expect(find.text(topic), findsOneWidget, reason: topic);
      }
      expect(find.text('Abu Hurairah'), findsOneWidget);
      expect(find.textContaining('One or two keywords'), findsOneWidget);
      // And the book filter.
      expect(find.text('All books'), findsOneWidget);
      expect(find.text('Sahih al-Bukhari'), findsOneWidget);
    });

    testWidgets('no clear button until something is typed', (tester) async {
      await pump(tester);
      expect(find.bySemanticsLabel('Clear'), findsNothing);
      await tester.enterText(field(), 'ab');
      await tester.pump();
      expect(find.bySemanticsLabel('Clear'), findsOneWidget);
    });
  });

  group('searching', () {
    testWidgets('tapping a suggestion fills the box and searches', (
      tester,
    ) async {
      stubSearch(
        (term, c) => [_h(c ?? 'bukhari', 1, 'Give charity every day')],
      );
      await pump(tester);

      await tester.tap(find.text('Charity'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field()).controller!.text, 'charity');
      expect(find.textContaining('hadith for “charity”'), findsOneWidget);
      expect(find.textContaining('Give charity every day'), findsWidgets);
      // The welcome help is gone.
      expect(find.text('Find a hadith'), findsNothing);
    });

    testWidgets('searches by itself when typing pauses (3+ letters)', (
      tester,
    ) async {
      stubSearch((term, c) => [_h(c ?? 'bukhari', 1, 'about $term')]);
      await pump(tester);

      await tester.enterText(field(), 'fa');
      await tester.pump(const Duration(seconds: 2));
      verifyNever(
        () => repo.search(
          any(),
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      );

      await tester.enterText(field(), 'fasting');
      await tester.pump(const Duration(milliseconds: 300));
      verifyNever(
        () => repo.search(
          any(),
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ); // not yet: still within the pause

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      verify(
        () => repo.search(
          'fasting',
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).called(10);
    });

    testWidgets('keeps typing: only the last word is searched', (tester) async {
      stubSearch((term, c) => [_h(c ?? 'bukhari', 1, term)]);
      await pump(tester);

      await tester.enterText(field(), 'cha');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(field(), 'charity');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      verifyNever(
        () => repo.search(
          'cha',
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      );
      verify(
        () => repo.search(
          'charity',
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).called(10);
    });

    testWidgets('submitting searches at once; the button too', (tester) async {
      stubSearch((term, c) => [_h(c ?? 'bukhari', 1, term)]);
      await pump(tester);

      await tester.enterText(field(), 'ab');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      verify(
        () => repo.search(
          'ab',
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).called(10);
    });

    testWidgets('clearing returns to the welcome help', (tester) async {
      stubSearch((term, c) => [_h(c ?? 'bukhari', 1, term)]);
      await pump(tester);
      await tester.tap(find.text('Charity'));
      await tester.pumpAndSettle();
      expect(find.text('Find a hadith'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Find a hadith'), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
    });

    testWidgets('the searched word is picked out in each result', (
      tester,
    ) async {
      stubSearch(
        (term, c) => [_h(c ?? 'bukhari', 1, 'Give charity every day')],
      );
      await pump(tester);
      await tester.tap(find.text('Charity'));
      await tester.pumpAndSettle();

      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((r) => r.text.toPlainText().contains('Give charity'))
          .first;
      final marked = <String>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan &&
            span.style?.fontWeight == FontWeight.w800 &&
            span.text != null) {
          marked.add(span.text!);
        }
        return true;
      });
      expect(marked, ['charity']);
    });
  });

  group('the book filter', () {
    testWidgets('choosing a book searches only in it', (tester) async {
      stubSearch((term, c) => [_h(c ?? 'bukhari', 1, 'about $term')]);
      await pump(tester);
      await tester.enterText(field(), 'mercy');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // The filter scrolls sideways: bring the book into view, as a user would.
      await tester.dragUntilVisible(
        find.text('Sahih Muslim'),
        find.byType(ListView).first,
        const Offset(-120, 0),
      );
      await tester.ensureVisible(find.text('Sahih Muslim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sahih Muslim'));
      await tester.pumpAndSettle();

      verify(() => repo.search('mercy', collection: 'muslim')).called(1);
    });

    testWidgets('opens in the book it was opened from', (tester) async {
      stubSearch((term, c) => [_h(c ?? 'bukhari', 1, 'about $term')]);
      await pump(tester, collection: 'nasai');
      await tester.enterText(field(), 'mercy');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      verify(() => repo.search('mercy', collection: 'nasai')).called(1);
    });
  });

  group('reopening', () {
    testWidgets('starts empty, not on the last search', (tester) async {
      stubSearch((term, c) => [_h('bukhari', 1, 'Give charity every day')]);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(FakeStorage()),
          hadithRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      // An earlier visit searched, and the shared state kept the results.
      await container
          .read(hadithSearchNotifierProvider.notifier)
          .search('charity');
      expect(container.read(hadithSearchNotifierProvider).value, isNotEmpty);

      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const HadithSearchScreen(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // Even on the very first frame the old results are not shown.
      expect(find.text('Find a hadith'), findsOneWidget);
      expect(find.textContaining('Give charity every day'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Find a hadith'), findsOneWidget);
      expect(container.read(hadithSearchNotifierProvider).value, isNull);
    });
  });

  group('by hadith number', () {
    testWidgets('a number with a book chosen opens that hadith', (
      tester,
    ) async {
      when(() => repo.findByNumber('bukhari', 2812)).thenAnswer(
        (_) async =>
            Success(_h('bukhari', 2812, 'Fight in the cause of Allah')),
      );
      await pump(tester, collection: 'bukhari');
      expect(find.text('Word or hadith number, e.g. 2812'), findsOneWidget);

      await tester.enterText(field(), '2812');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      verify(() => repo.findByNumber('bukhari', 2812)).called(1);
      verifyNever(
        () => repo.search(any(), collection: any(named: 'collection')),
      );
      expect(find.text('#2812'), findsOneWidget);
      expect(find.textContaining('Fight in the cause of Allah'), findsWidgets);
    });

    testWidgets('a number the book does not have says so', (tester) async {
      when(
        () => repo.findByNumber('bukhari', 99999),
      ).thenAnswer((_) async => const Success(null));
      await pump(tester, collection: 'bukhari');

      await tester.enterText(field(), '99999');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.textContaining('No hadith numbered 99999'), findsOneWidget);
      expect(find.text('Search all books'), findsNothing);
    });

    testWidgets('with no book chosen a number is searched as a word', (
      tester,
    ) async {
      stubSearch((term, c) => const []);
      await pump(tester);

      await tester.enterText(field(), '2812');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      verifyNever(() => repo.findByNumber(any(), any()));
    });
  });

  group('nothing found', () {
    testWidgets('says what to try, and offers the topics', (tester) async {
      stubSearch((term, c) => const []);
      await pump(tester);
      await tester.enterText(field(), 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('No hadith found for “zzzz”'), findsOneWidget);
      expect(find.text('Check the spelling.'), findsOneWidget);
      expect(
        find.textContaining('one keyword instead of a sentence'),
        findsOneWidget,
      );
      expect(find.text('Charity'), findsOneWidget); // a way out
      expect(find.text('Search all books'), findsNothing);
    });

    testWidgets('inside one book it offers to search them all', (tester) async {
      stubSearch((term, c) => c == null ? [_h('bukhari', 1, term)] : const []);
      await pump(tester, collection: 'qudsi');
      await tester.enterText(field(), 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No hadith found for “zzzz” in'),
        findsOneWidget,
      );
      await tester.tap(find.text('Search all books'));
      await tester.pumpAndSettle();
      verify(
        () => repo.search(
          'zzzz',
          collection: 'bukhari',
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });
  });

  group('in Urdu', () {
    testWidgets('the hint and suggestions are in Urdu, and work', (
      tester,
    ) async {
      stubSearch((term, c) => [_h(c ?? 'bukhari', 1, 'Give $term daily')]);
      await pump(tester, language: 'urdu');

      expect(
        tester.widget<TextField>(field()).decoration!.hintText,
        'Search by word, e.g. fasting or روزہ',
      );
      expect(find.text('صدقہ'), findsWidgets);
      expect(find.textContaining('Results are shown in Urdu.'), findsOneWidget);
      expect(find.textContaining('type common topics in Urdu'), findsOneWidget);

      await tester.tap(find.text('صدقہ').first);
      await tester.pumpAndSettle();

      // The Urdu word was searched by its English one, and says so.
      verify(
        () => repo.search(
          'charity',
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).called(10);
      expect(
        find.text('Searched the English translation for “charity”.'),
        findsOneWidget,
      );
    });

    testWidgets('an Urdu word that is not a topic is explained, not searched', (
      tester,
    ) async {
      await pump(tester, language: 'urdu');
      await tester.enterText(field(), 'نامعلوم');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('That word can’t be searched yet'), findsOneWidget);
      expect(find.textContaining('needs English words'), findsOneWidget);
      verifyNever(
        () => repo.search(
          any(),
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      );
    });
  });
}
