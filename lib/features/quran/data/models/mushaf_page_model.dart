import '../../domain/entities/mushaf_page.dart';
import 'mushaf_word_model.dart';

class MushafPageModel {
  final int page;
  final int totalPages;
  final int linesPerPage;
  final List<MushafWordModel> words;

  const MushafPageModel({
    required this.page,
    required this.totalPages,
    required this.linesPerPage,
    required this.words,
  });

  factory MushafPageModel.fromJson(Map<String, dynamic> json) {
    return MushafPageModel(
      page: json['page'] as int,
      totalPages: json['total_pages'] as int,
      linesPerPage: json['lines_per_page'] as int,
      words: (json['words'] as List)
          .map((e) => MushafWordModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'page': page,
    'total_pages': totalPages,
    'lines_per_page': linesPerPage,
    'words': words.map((w) => w.toJson()).toList(),
  };

  MushafPage toEntity() => MushafPage(
    page: page,
    totalPages: totalPages,
    linesPerPage: linesPerPage,
    words: words.map((w) => w.toEntity()).toList(),
  );
}
