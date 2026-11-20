import 'hadith_search_topics.dart';

/// What the reader typed, and what we can actually search for.
///
/// The hadith source matches the English translation text only, as an exact
/// phrase. So the typed text is turned into English search words: English
/// input is used as typed; Urdu input is mapped word by word through the known
/// topics; anything else in another script can't be searched.
class HadithSearchQuery {
  /// What was typed, with spacing tidied.
  final String typed;

  /// The English words to search for. Empty when nothing searchable remains.
  final List<String> words;

  /// The input used a script the search can't read (Urdu/Arabic) and at least
  /// one word wasn't a topic we know. With no [words] left, nothing is searched.
  final bool hasUnknownScript;

  /// Part of the query was Urdu and was translated to English words.
  final bool translatedFromUrdu;

  const HadithSearchQuery._({
    required this.typed,
    required this.words,
    required this.hasUnknownScript,
    required this.translatedFromUrdu,
  });

  /// The words as the single search phrase the source expects.
  String get term => words.join(' ');

  /// The hadith number typed, when that is all that was typed ("2812" or
  /// "#2812", in Western or Arabic-Indic digits); null otherwise.
  int? get number {
    final m = RegExp(r'^#?\s*([0-9٠-٩۰-۹]{1,5})$').firstMatch(typed);
    if (m == null) return null;
    final digits = m.group(1)!.runes.map((r) {
      if (r >= 0x0660 && r <= 0x0669) return r - 0x0660;
      if (r >= 0x06F0 && r <= 0x06F9) return r - 0x06F0;
      return r - 0x30;
    }).join();
    final n = int.tryParse(digits);
    return n == null || n < 1 ? null : n;
  }

  bool get isEmpty => typed.isEmpty;
  bool get isSearchable => words.isNotEmpty;
  bool get isMultiWord => words.length >= 2;

  static final _arabicScript = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

  static HadithSearchQuery parse(String input) {
    final typed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (typed.isEmpty) {
      return const HadithSearchQuery._(
        typed: '',
        words: [],
        hasUnknownScript: false,
        translatedFromUrdu: false,
      );
    }

    final words = <String>[];
    var unknown = false;
    var translated = false;
    for (final raw in typed.split(' ')) {
      if (_arabicScript.hasMatch(raw)) {
        final english = HadithSearchTopics.englishFor(raw);
        if (english == null) {
          unknown = true;
        } else {
          translated = true;
          // A topic can be several words ("day of resurrection").
          words.addAll(english.split(' '));
        }
      } else {
        final cleaned = raw.replaceAll(
          RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
          '',
        );
        if (cleaned.isNotEmpty) words.add(cleaned);
      }
    }
    return HadithSearchQuery._(
      typed: typed,
      words: words,
      hasUnknownScript: unknown,
      translatedFromUrdu: translated,
    );
  }
}
