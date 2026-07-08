import 'package:equatable/equatable.dart';

class MushafWord extends Equatable {
  final int position;
  final String textUthmani;
  final String textUthmaniTajweed;
  final int lineNumber;
  final String charTypeName;
  final String verseKey;

  const MushafWord({
    required this.position,
    required this.textUthmani,
    required this.textUthmaniTajweed,
    required this.lineNumber,
    required this.charTypeName,
    required this.verseKey,
  });

  @override
  List<Object?> get props => [verseKey, position];
}

class MushafPage extends Equatable {
  final int page;
  final int totalPages;
  final int linesPerPage;
  final List<MushafWord> words;

  const MushafPage({
    required this.page,
    required this.totalPages,
    required this.linesPerPage,
    required this.words,
  });

  /// Words grouped by their mushaf line — exactly what a page-rendering
  /// UI needs, and keeping this on the entity means the widget doesn't
  /// reimplement grouping logic.
  Map<int, List<MushafWord>> get wordsByLine {
    final map = <int, List<MushafWord>>{};
    for (final word in words) {
      map.putIfAbsent(word.lineNumber, () => []).add(word);
    }
    return map;
  }

  @override
  List<Object?> get props => [page];
}
