import 'dart:async';

import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/features/hadith/domain/hadith_search_excerpt.dart';
import 'package:deen_companion/features/hadith/domain/hadith_search_query.dart';
import 'package:deen_companion/features/hadith/domain/hadith_search_topics.dart';
import 'package:deen_companion/features/hadith/domain/repositories/hadith_repository.dart';
import 'package:deen_companion/features/hadith/presentation/providers/hadith_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements HadithRepository {}

Hadith _h(String collection, int n, [String english = 'text']) => Hadith(
  id: '$collection-$n',
  collection: collection,
  collectionName: collection,
  hadithNumber: n,
  arabic: 'ar',
  english: english,
  grade: 'Sahih',
);

void main() {
  group('HadithSearchQuery.parse', () {
    test('English is used as typed, with spacing tidied', () {
      final q = HadithSearchQuery.parse('  prayer   fasting ');
      expect(q.typed, 'prayer fasting');
      expect(q.words, ['prayer', 'fasting']);
      expect(q.term, 'prayer fasting');
      expect(q.isMultiWord, isTrue);
      expect(q.isSearchable, isTrue);
      expect(q.translatedFromUrdu, isFalse);
    });

    test('blank is empty', () {
      expect(HadithSearchQuery.parse('   ').isEmpty, isTrue);
      expect(HadithSearchQuery.parse('').isSearchable, isFalse);
    });

    test('punctuation around words is dropped', () {
      expect(HadithSearchQuery.parse('"charity",').words, ['charity']);
      expect(HadithSearchQuery.parse('Allāh').words, ['Allāh']);
    });

    test('a known Urdu topic is searched by its English word', () {
      final q = HadithSearchQuery.parse('صدقہ');
      expect(q.words, ['charity']);
      expect(q.translatedFromUrdu, isTrue);
      expect(q.hasUnknownScript, isFalse);
    });

    test('spelling variants and marks still find the topic', () {
      for (final typed in ['زکوٰۃ', 'زکوة', 'زکاۃ', 'زَکوٰۃ']) {
        expect(HadithSearchQuery.parse(typed).words, ['zakat'], reason: typed);
      }
      expect(HadithSearchQuery.parse('شادی').words, ['marriage']);
    });

    test('a multi-word topic expands to its words', () {
      expect(HadithSearchQuery.parse('قیامت').words, [
        'day',
        'of',
        'resurrection',
      ]);
    });

    test('Urdu and English can be mixed', () {
      expect(HadithSearchQuery.parse('نماز mosque').words, [
        'prayer',
        'mosque',
      ]);
    });

    test('Urdu that is not a known topic can not be searched', () {
      final q = HadithSearchQuery.parse('نامعلوم');
      expect(q.isSearchable, isFalse);
      expect(q.hasUnknownScript, isTrue);
      expect(q.words, isEmpty);
    });

    test('known words are kept when another Urdu word is unknown', () {
      final q = HadithSearchQuery.parse('نماز نامعلوم');
      expect(q.words, ['prayer']);
      expect(q.hasUnknownScript, isTrue);
      expect(q.isSearchable, isTrue);
    });
  });

  group('HadithSearchQuery.number', () {
    test('reads a lone number, with or without #', () {
      expect(HadithSearchQuery.parse('2812').number, 2812);
      expect(HadithSearchQuery.parse(' #2812 ').number, 2812);
    });

    test('reads Arabic-Indic and Urdu digits', () {
      expect(HadithSearchQuery.parse('٢٨١٢').number, 2812);
      expect(HadithSearchQuery.parse('۲۸۱۲').number, 2812);
    });

    test('is null for words, mixed text, zero and huge numbers', () {
      expect(HadithSearchQuery.parse('fasting').number, isNull);
      expect(HadithSearchQuery.parse('prayer 5').number, isNull);
      expect(HadithSearchQuery.parse('0').number, isNull);
      expect(HadithSearchQuery.parse('123456').number, isNull);
    });
  });

  group('HadithSearchTopics', () {
    test('every suggestion has an English word and an Urdu label', () {
      for (final t in HadithSearchTopics.featured) {
        expect(t.english, isNotEmpty);
        expect(t.urdu, isNotEmpty);
        expect(t.englishLabel[0], t.englishLabel[0].toUpperCase());
        // The Urdu label, typed, must find the same English word.
        expect(HadithSearchTopics.englishFor(t.urdu), t.english);
      }
    });

    test('no Urdu spelling belongs to two different topics', () {
      final owner = <String, String>{};
      for (final t in [
        ...HadithSearchTopics.featured,
        ...HadithSearchTopics.more,
      ]) {
        for (final spelling in [t.urdu, ...t.aliases]) {
          final key = HadithSearchTopics.normalizeUrdu(spelling);
          // The same topic may list a spelling twice (it normalises the same);
          // two topics must not.
          expect(
            owner.putIfAbsent(key, () => t.english),
            t.english,
            reason: 'ambiguous: $spelling',
          );
        }
      }
    });
  });

  group('HadithSearchExcerpt', () {
    const long =
        'Narrated Abu Huraira: the Prophet said many things about many '
        'matters before at last he spoke of charity and the reward of it.';

    test('a match near the start leaves the text alone', () {
      expect(HadithSearchExcerpt.around(long, ['Narrated']), long);
      expect(HadithSearchExcerpt.around(long, ['zzz']), long);
      expect(HadithSearchExcerpt.around(long, []), long);
    });

    test('a match deep in the text is brought into view', () {
      final out = HadithSearchExcerpt.around(long, ['charity'], lead: 20);
      expect(out, startsWith('… '));
      expect(out, contains('charity'));
      expect(out.length, lessThan(long.length));
      // Starts on a whole word, not part of one.
      expect(out.substring(2), isNot(startsWith('ny ')));
    });

    test('segments mark every match, ignoring case', () {
      final segs = HadithSearchExcerpt.segments('Charity and charity.', [
        'charity',
      ]);
      expect(segs.where((s) => s.match).map((s) => s.text), [
        'Charity',
        'charity',
      ]);
      expect(segs.map((s) => s.text).join(), 'Charity and charity.');
    });

    test('no words or no text gives one plain segment', () {
      expect(HadithSearchExcerpt.segments('abc', []), [
        (text: 'abc', match: false),
      ]);
      expect(HadithSearchExcerpt.segments('', ['a']), [
        (text: '', match: false),
      ]);
    });

    test('special characters in a word are not treated as a pattern', () {
      expect(
        HadithSearchExcerpt.segments('a.b a+b', ['a.b']).where((s) => s.match),
        hasLength(1),
      );
    });
  });

  group('HadithSearchNotifier', () {
    late _Repo repo;
    late ProviderContainer container;

    setUp(() {
      repo = _Repo();
      container = ProviderContainer(
        overrides: [hadithRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    void stubAll(
      Future<Result<List<Hadith>>> Function(String term, String? c, int limit)
      f,
    ) {
      when(
        () => repo.search(
          any(),
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((i) {
        return f(
          i.positionalArguments.first as String,
          i.namedArguments[#collection] as String?,
          i.namedArguments[#limit] as int,
        );
      });
    }

    HadithSearchNotifier notifier() =>
        container.read(hadithSearchNotifierProvider.notifier);
    List<Hadith>? results() =>
        container.read(hadithSearchNotifierProvider).value;
    HadithSearchInfo? info() => container.read(hadithSearchInfoProvider);

    test('all books: every book is asked, and the hits are mixed', () async {
      stubAll(
        (term, c, limit) async =>
            Success([for (var i = 1; i <= 3; i++) _h(c!, i)]),
      );
      await notifier().search('charity');

      for (final key in HadithSearchNotifier.allCollections) {
        verify(
          () => repo.search(
            'charity',
            collection: key,
            limit: HadithSearchNotifier.perBook,
          ),
        ).called(1);
      }
      final hits = results()!;
      expect(hits, hasLength(30));
      // Mixed, not one book's three followed by the next: the first ten
      // are one hadith from each book.
      expect(
        hits.take(10).map((h) => h.collection).toSet(),
        HadithSearchNotifier.allCollections.toSet(),
      );
      expect(info()!.mode, HadithSearchMode.exact);
      expect(info()!.collection, isNull);
    });

    test('mayHaveMore is set when a book filled its share', () async {
      stubAll(
        (term, c, limit) async => Success([
          for (var i = 0; i < (c == 'bukhari' ? limit : 1); i++) _h(c!, i),
        ]),
      );
      await notifier().search('charity');
      expect(info()!.mayHaveMore, isTrue);

      stubAll((term, c, limit) async => Success([_h(c!, 1)]));
      await notifier().search('mercy');
      expect(info()!.mayHaveMore, isFalse);
    });

    test(
      'one book: a single search, with that book named in the info',
      () async {
        when(
          () => repo.search('intent', collection: 'muslim'),
        ).thenAnswer((_) async => Success([_h('muslim', 1)]));
        await notifier().search(' intent ', collection: 'muslim');

        expect(results(), hasLength(1));
        expect(info()!.collection, 'muslim');
        verify(() => repo.search('intent', collection: 'muslim')).called(1);
        verifyNever(
          () => repo.search(
            any(),
            collection: 'bukhari',
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test(
      'a book that fails does not sink the search; all failing does',
      () async {
        stubAll(
          (term, c, limit) async => c == 'muslim'
              ? const Error(NetworkFailure())
              : Success([_h(c!, 1)]),
        );
        await notifier().search('charity');
        expect(
          results(),
          hasLength(HadithSearchNotifier.allCollections.length - 1),
        );

        stubAll((term, c, limit) async => const Error(NetworkFailure()));
        await notifier().search('mercy');
        expect(
          container.read(hadithSearchNotifierProvider).error,
          isA<NetworkFailure>(),
        );
      },
    );

    test('the retry only returns hadith containing every word', () async {
      stubAll((term, c, limit) async {
        if (term == 'charity paradise') return const Success(<Hadith>[]);
        return Success([
          _h(c!, 1, 'Give charity and enter Paradise'),
          _h(c, 2, 'Give charity daily'),
          _h(c, 3, 'The gates of paradise are open'),
        ]);
      });
      await notifier().search('charity paradise');

      final hits = results()!;
      expect(hits, isNotEmpty);
      for (final h in hits) {
        final t = h.english.toLowerCase();
        expect(t.contains('charity') && t.contains('paradise'), isTrue);
      }
      expect(info()!.mode, HadithSearchMode.allWords);
      // Mixed across books too.
      expect(hits.map((h) => h.collection).toSet().length, greaterThan(1));
    });

    test('a single word that finds nothing is not retried', () async {
      stubAll((term, c, limit) async => const Success(<Hadith>[]));
      await notifier().search('zzzz');
      expect(results(), isEmpty);
      expect(info()!.mode, HadithSearchMode.exact);
      // Exactly one round of per-book searches.
      verify(
        () => repo.search(
          'zzzz',
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).called(HadithSearchNotifier.allCollections.length);
    });

    test('a retry that finds nothing either leaves the empty result', () async {
      stubAll((term, c, limit) async {
        if (term.contains(' ')) return const Success(<Hadith>[]);
        return Success([_h(c!, 1, 'nothing relevant')]);
      });
      await notifier().search('alpha bravo');
      expect(results(), isEmpty);
      expect(info()!.mode, HadithSearchMode.exact);
    });

    test('Urdu: a known topic searches its English word', () async {
      stubAll((term, c, limit) async => Success([_h(c!, 1)]));
      await notifier().search('صدقہ');

      verify(
        () => repo.search(
          'charity',
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).called(HadithSearchNotifier.allCollections.length);
      expect(info()!.query.translatedFromUrdu, isTrue);
      expect(info()!.query.typed, 'صدقہ');
    });

    test(
      'Urdu that is not a topic: no request, an explained empty result',
      () async {
        await notifier().search('نامعلوم');

        verifyNever(
          () => repo.search(
            any(),
            collection: any(named: 'collection'),
            limit: any(named: 'limit'),
          ),
        );
        expect(results(), isEmpty);
        expect(info()!.query.isSearchable, isFalse);
        expect(info()!.query.hasUnknownScript, isTrue);
      },
    );

    test('blank clears the results and the info', () async {
      stubAll((term, c, limit) async => Success([_h(c!, 1)]));
      await notifier().search('charity');
      expect(info(), isNotNull);

      await notifier().search('   ');
      expect(results(), isNull);
      expect(info(), isNull);
    });

    test('an older, slower search never overwrites a newer one', () async {
      final slow = Completer<Result<List<Hadith>>>();
      stubAll((term, c, limit) {
        if (term == 'slowword') return slow.future;
        return Future.value(Success([_h(c!, 9, 'fast result')]));
      });

      final first = notifier().search('slowword');
      await notifier().search('fastword');
      expect(results()!.first.english, 'fast result');

      slow.complete(Success([_h('bukhari', 1, 'SLOW')]));
      await first;
      expect(
        results()!.every((h) => h.english == 'fast result'),
        isTrue,
        reason: 'the stale search must not replace the newer results',
      );
      expect(info()!.query.typed, 'fastword');
    });
  });
}
