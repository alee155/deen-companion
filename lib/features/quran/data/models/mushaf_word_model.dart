import '../../domain/entities/mushaf_page.dart';

class MushafWordModel {
  final int position;
  final String textUthmani;
  final String textUthmaniTajweed;
  final int lineNumber;
  final String charTypeName;
  final String verseKey;

  const MushafWordModel({
    required this.position,
    required this.textUthmani,
    required this.textUthmaniTajweed,
    required this.lineNumber,
    required this.charTypeName,
    required this.verseKey,
  });

  factory MushafWordModel.fromJson(Map<String, dynamic> json) {
    return MushafWordModel(
      position: json['position'] as int,
      textUthmani: json['text_uthmani'] as String,
      textUthmaniTajweed: json['text_uthmani_tajweed'] as String,
      lineNumber: json['line_number'] as int,
      charTypeName: json['char_type_name'] as String,
      verseKey: json['verse_key'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'position': position,
    'text_uthmani': textUthmani,
    'text_uthmani_tajweed': textUthmaniTajweed,
    'line_number': lineNumber,
    'char_type_name': charTypeName,
    'verse_key': verseKey,
  };

  MushafWord toEntity() => MushafWord(
    position: position,
    textUthmani: textUthmani,
    textUthmaniTajweed: textUthmaniTajweed,
    lineNumber: lineNumber,
    charTypeName: charTypeName,
    verseKey: verseKey,
  );
}
