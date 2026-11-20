/// Helpers for showing *why* a hadith matched: the part of its text around the
/// searched words, with those words picked out.
class HadithSearchExcerpt {
  HadithSearchExcerpt._();

  /// [text] starting a little before the first match of any of [words], cut at
  /// a word boundary and led by "… " — so a match deep in a long hadith is
  /// visible in a three-line preview. Unchanged if the match is near the start
  /// or nothing matches.
  static String around(String text, List<String> words, {int lead = 70}) {
    final first = _firstMatch(text, words);
    if (first == null || first <= lead) return text;

    var start = first - lead;
    // Start at a word, not in the middle of one.
    final space = text.indexOf(' ', start);
    if (space != -1 && space < first) start = space + 1;
    return '… ${text.substring(start)}';
  }

  /// [text] split into runs, each marked as a match of one of [words] or not.
  /// Matching ignores case. Empty words are ignored.
  static List<({String text, bool match})> segments(
    String text,
    List<String> words,
  ) {
    final usable = [
      for (final w in words)
        if (w.trim().isNotEmpty) RegExp.escape(w.trim()),
    ];
    if (usable.isEmpty || text.isEmpty) return [(text: text, match: false)];

    final pattern = RegExp(usable.join('|'), caseSensitive: false);
    final out = <({String text, bool match})>[];
    var cursor = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > cursor) {
        out.add((text: text.substring(cursor, m.start), match: false));
      }
      out.add((text: m.group(0)!, match: true));
      cursor = m.end;
    }
    if (cursor < text.length) {
      out.add((text: text.substring(cursor), match: false));
    }
    return out.isEmpty ? [(text: text, match: false)] : out;
  }

  static int? _firstMatch(String text, List<String> words) {
    final lower = text.toLowerCase();
    int? best;
    for (final w in words) {
      final word = w.trim().toLowerCase();
      if (word.isEmpty) continue;
      final at = lower.indexOf(word);
      if (at != -1 && (best == null || at < best)) best = at;
    }
    return best;
  }
}
