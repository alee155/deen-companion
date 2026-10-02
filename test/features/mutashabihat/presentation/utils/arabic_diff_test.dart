import 'package:deen_companion/features/mutashabihat/presentation/utils/arabic_diff.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> changed(List<DiffToken> t) => [
  for (final x in t)
    if (x.changed) x.text,
];
List<String> texts(List<DiffToken> t) => [for (final x in t) x.text];

void main() {
  group('diffArabicVerses', () {
    test('identical verses have no changed tokens', () {
      final d = diffArabicVerses(
        'الحمد لله رب العالمين',
        'الحمد لله رب العالمين',
      );
      expect(changed(d.a), isEmpty);
      expect(changed(d.b), isEmpty);
    });

    test('a single substituted word is flagged on both sides', () {
      final d = diffArabicVerses('إن الله غفور رحيم', 'إن الله عزيز رحيم');
      expect(changed(d.a), ['غفور']);
      expect(changed(d.b), ['عزيز']);
      expect(texts(d.a), ['إن', 'الله', 'غفور', 'رحيم']);
    });

    test('an inserted word only appears as changed in the longer verse', () {
      final d = diffArabicVerses(
        'وما الله بغافل عما تعملون',
        'وما الله بغافل عما يعملون جميعا',
      );
      expect(changed(d.b), containsAll(['يعملون', 'جميعا']));
      expect(changed(d.a), ['تعملون']);
    });

    test('diacritics are ignored when matching but preserved in output', () {
      final d = diffArabicVerses(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ',
        'بسم الله الرحمن',
      );
      expect(changed(d.a), isEmpty);
      expect(changed(d.b), isEmpty);
      expect(d.a.first.text, 'بِسْمِ');
    });

    test('verses below the 50% similarity threshold highlight nothing', () {
      final d = diffArabicVerses('قل هو الله أحد', 'تبت يدا أبي لهب وتب');
      expect(changed(d.a), isEmpty);
      expect(changed(d.b), isEmpty);
      expect(d.a, hasLength(4));
      expect(d.b, hasLength(5));
    });

    test('exactly 50% similarity is still highlighted', () {
      // 2 of 4 words in common -> 0.5 >= threshold.
      final d = diffArabicVerses('أ ب ج د', 'أ ب س ص');
      expect(changed(d.a), ['ج', 'د']);
      expect(changed(d.b), ['س', 'ص']);
    });

    test('empty inputs produce empty token lists without throwing', () {
      final both = diffArabicVerses('', '');
      expect(both.a, isEmpty);
      expect(both.b, isEmpty);

      final one = diffArabicVerses('كلمة', '   ');
      expect(texts(one.a), ['كلمة']);
      expect(one.b, isEmpty);
      expect(changed(one.a), isEmpty);
    });

    test('extra whitespace is tokenised away', () {
      final d = diffArabicVerses('  أ   ب  ', 'أ ب');
      expect(texts(d.a), ['أ', 'ب']);
      expect(changed(d.a), isEmpty);
    });
  });

  group('baseDiffTokens', () {
    test('marks a base word if it differs from ANY of the others', () {
      final tokens = baseDiffTokens('أ ب ج د', ['أ ب س د', 'أ ص ج د']);
      expect(changed(tokens), ['ب', 'ج']);
      expect(texts(tokens), ['أ', 'ب', 'ج', 'د']);
    });

    test('no others -> nothing changed', () {
      expect(changed(baseDiffTokens('أ ب', const [])), isEmpty);
    });

    test('dissimilar others contribute no highlights', () {
      expect(changed(baseDiffTokens('أ ب ج د', ['س ص ع ف'])), isEmpty);
    });
  });

  group('similarDiffTokens', () {
    test('returns the similar verse side of the diff', () {
      final tokens = similarDiffTokens('أ ب ج', 'أ س ج');
      expect(texts(tokens), ['أ', 'س', 'ج']);
      expect(changed(tokens), ['س']);
    });
  });
}
