/// A topic a reader might look for, with the English word that actually finds
/// it and how it is written in Urdu.
///
/// The hadith source can only be searched by English words, so for an Urdu
/// reader these are a bridge both ways: the suggestions are shown in Urdu, and
/// typing the Urdu word searches by its English one.
class HadithSearchTopic {
  /// The English word searched for (it appears in the translation text).
  final String english;

  /// How it is written in Urdu, as shown on a suggestion.
  final String urdu;

  /// Other spellings someone might type for the same word.
  final List<String> aliases;

  const HadithSearchTopic(this.english, this.urdu, [this.aliases = const []]);

  /// Capitalised, for a suggestion label.
  String get englishLabel =>
      '${english[0].toUpperCase()}${english.substring(1)}';
}

class HadithSearchTopics {
  HadithSearchTopics._();

  /// Shown as suggestions. A short, varied set people commonly ask about.
  static const featured = <HadithSearchTopic>[
    HadithSearchTopic('prayer', 'نماز'),
    HadithSearchTopic('fasting', 'روزہ'),
    HadithSearchTopic('charity', 'صدقہ'),
    HadithSearchTopic('patience', 'صبر'),
    HadithSearchTopic('parents', 'والدین'),
    HadithSearchTopic('paradise', 'جنت'),
    HadithSearchTopic('intention', 'نیت'),
    HadithSearchTopic('knowledge', 'علم'),
    HadithSearchTopic('repentance', 'توبہ'),
    HadithSearchTopic('truth', 'سچ', ['سچائی']),
    HadithSearchTopic('marriage', 'نکاح', ['شادی']),
    HadithSearchTopic('mercy', 'رحمت'),
  ];

  /// More words an Urdu reader can type, beyond the suggestions.
  static const more = <HadithSearchTopic>[
    HadithSearchTopic('zakat', 'زکوٰۃ', ['زکوة', 'زکاۃ', 'زکات']),
    HadithSearchTopic('hajj', 'حج'),
    HadithSearchTopic('umrah', 'عمرہ'),
    HadithSearchTopic('ramadan', 'رمضان'),
    HadithSearchTopic('friday', 'جمعہ'),
    HadithSearchTopic('ablution', 'وضو'),
    HadithSearchTopic('mosque', 'مسجد'),
    HadithSearchTopic('faith', 'ایمان'),
    HadithSearchTopic('sin', 'گناہ'),
    HadithSearchTopic('hell', 'جہنم', ['دوزخ']),
    HadithSearchTopic('death', 'موت'),
    HadithSearchTopic('anger', 'غصہ'),
    HadithSearchTopic('lie', 'جھوٹ'),
    HadithSearchTopic('neighbor', 'پڑوسی', ['ہمسایہ']),
    HadithSearchTopic('orphan', 'یتیم'),
    HadithSearchTopic('mother', 'ماں'),
    HadithSearchTopic('father', 'باپ'),
    HadithSearchTopic('trade', 'تجارت'),
    HadithSearchTopic('oath', 'قسم'),
    HadithSearchTopic('modesty', 'حیا'),
    HadithSearchTopic('trust', 'امانت'),
    HadithSearchTopic('supplication', 'دعا'),
    HadithSearchTopic('day of resurrection', 'قیامت'),
    HadithSearchTopic('character', 'اخلاق'),
    HadithSearchTopic('provision', 'رزق'),
    HadithSearchTopic('greeting', 'سلام'),
    HadithSearchTopic('quran', 'قرآن'),
    HadithSearchTopic('eid', 'عید'),
  ];

  /// Names worth trying. Spelled the way they match across books.
  static const narrators = <String>['Abu Hurairah', 'Aisha', 'Ibn Abbas'];

  static final Map<String, String> _byUrdu = _build();

  static Map<String, String> _build() {
    final map = <String, String>{};
    for (final t in [...featured, ...more]) {
      map[normalizeUrdu(t.urdu)] = t.english;
      for (final alias in t.aliases) {
        map[normalizeUrdu(alias)] = t.english;
      }
    }
    return map;
  }

  /// The English search word for an Urdu word, or null if it isn't one we know.
  static String? englishFor(String urduWord) =>
      _byUrdu[normalizeUrdu(urduWord)];

  /// Strips marks and unifies letter forms that differ between keyboards, so
  /// the same word typed two ways is found.
  static String normalizeUrdu(String word) => word
      .replaceAll(RegExp(r'[ً-ٰٟۖ-ۭ‌‍]'), '')
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ۃ', 'ہ')
      .replaceAll('ة', 'ہ')
      .replaceAll('ھ', 'ہ')
      .replaceAll(RegExp(r'[^؀-ۿa-zA-Z0-9]'), '');
}
