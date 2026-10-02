/// One word of a verse, tagged with whether it's part of what makes this
/// verse different from the one it's being compared against.
class DiffToken {
  final String text;
  final bool changed;
  const DiffToken(this.text, {this.changed = false});
}

List<String> _tokenize(String text) =>
    text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Arabic diacritics (tashkeel) and Quranic recitation/annotation marks —
/// stripped only for the *comparison*, never for display. Two spellings of
/// the same word can carry slightly different harakat between data sources;
/// without normalizing first, a word that reads identically to a human gets
/// flagged as "different" purely over a diacritic, burying the handful of
/// genuinely different words in noise.
final _diacriticsPattern = RegExp(
  r'[ؐ-ًؚ-ٰٟۖ-ۭࣔ-ࣣ࣡-ࣿ]',
);

String _normalize(String word) => word.replaceAll(_diacriticsPattern, '');

/// Below this fraction of matching words, two verses don't share enough
/// text for a word-level diff to mean anything — they're "mutashabihat" by
/// theme or a short recurring phrase, not near-duplicates. Highlighting
/// every word in that case would look like the feature is broken rather
/// than like a real "here's the difference," so nothing is marked instead.
const _minSimilarityToHighlight = 0.5;

/// Word-level diff between two verse strings, via longest-common-subsequence
/// on whitespace-tokenized words (matched diacritic-insensitively).
///
/// Mutashabihat verses are "confusable" precisely because they're almost
/// identical — usually differing by a single word or a short phrase. Making
/// someone eyeball two full ayahs to spot that difference defeats the point
/// of the feature; this surfaces it directly so the highlighted words *are*
/// the answer to "why do these get mixed up."
({List<DiffToken> a, List<DiffToken> b}) diffArabicVerses(String a, String b) {
  final aWords = _tokenize(a);
  final bWords = _tokenize(b);
  final aNorm = aWords.map(_normalize).toList();
  final bNorm = bWords.map(_normalize).toList();
  final m = aWords.length, n = bWords.length;

  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = m - 1; i >= 0; i--) {
    for (var j = n - 1; j >= 0; j--) {
      dp[i][j] = aNorm[i] == bNorm[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  final longestMax = m > n ? m : n;
  final similarEnough =
      longestMax > 0 && dp[0][0] / longestMax >= _minSimilarityToHighlight;

  if (!similarEnough) {
    return (
      a: [for (final w in aWords) DiffToken(w)],
      b: [for (final w in bWords) DiffToken(w)],
    );
  }

  final aMatched = List<bool>.filled(m, false);
  final bMatched = List<bool>.filled(n, false);
  var i = 0, j = 0;
  while (i < m && j < n) {
    if (aNorm[i] == bNorm[j]) {
      aMatched[i] = true;
      bMatched[j] = true;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  return (
    a: [
      for (var k = 0; k < m; k++) DiffToken(aWords[k], changed: !aMatched[k]),
    ],
    b: [
      for (var k = 0; k < n; k++) DiffToken(bWords[k], changed: !bMatched[k]),
    ],
  );
}

/// The base verse is compared against every similar verse in its group, not
/// just one — a word is worth highlighting on the base if it differs from
/// the base in *any* of them, so the base reads as "here's everywhere this
/// verse tends to vary across its lookalikes."
List<DiffToken> baseDiffTokens(String base, List<String> others) {
  final baseWords = _tokenize(base);
  final changed = List<bool>.filled(baseWords.length, false);
  for (final other in others) {
    final diff = diffArabicVerses(base, other);
    for (var k = 0; k < diff.a.length && k < changed.length; k++) {
      if (diff.a[k].changed) changed[k] = true;
    }
  }
  return [
    for (var k = 0; k < baseWords.length; k++)
      DiffToken(baseWords[k], changed: changed[k]),
  ];
}

/// The similar verse's own words, tagged by where they diverge from the base.
List<DiffToken> similarDiffTokens(String base, String similar) =>
    diffArabicVerses(base, similar).b;
