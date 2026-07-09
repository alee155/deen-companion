import '../../domain/entities/mutashabihat_entry.dart';
import 'mutashabihat_verse_ref_model.dart';

class MutashabihatEntryModel {
  final MutashabihatVerseRefModel verse;
  final List<MutashabihatVerseRefModel> similarVerses;

  const MutashabihatEntryModel({
    required this.verse,
    required this.similarVerses,
  });

  factory MutashabihatEntryModel.fromJson(Map<String, dynamic> json) {
    return MutashabihatEntryModel(
      verse: MutashabihatVerseRefModel.fromJson(json),
      similarVerses: (json['similar_verses'] as List)
          .map(
            (e) =>
                MutashabihatVerseRefModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    ...verse.toJson(),
    'similar_verses': similarVerses.map((v) => v.toJson()).toList(),
  };

  MutashabihatEntry toEntity() => MutashabihatEntry(
    verse: verse.toEntity(),
    similarVerses: similarVerses.map((v) => v.toEntity()).toList(),
  );
}
