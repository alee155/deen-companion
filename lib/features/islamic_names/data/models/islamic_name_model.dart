import 'package:deen_companion/features/islamic_names/domain/entities/islamic_name.dart';

class IslamicNameModel {
  final int id;
  final String name;
  final String arabic;
  final String gender;
  final String meaning;
  final String origin;
  final String? root;
  final String note;

  const IslamicNameModel({
    required this.id,
    required this.name,
    required this.arabic,
    required this.gender,
    required this.meaning,
    required this.origin,
    this.root,
    required this.note,
  });

  factory IslamicNameModel.fromJson(Map<String, dynamic> json) {
    return IslamicNameModel(
      id: json['id'] as int,
      name: json['name'] as String,
      arabic: json['arabic'] as String,
      gender: json['gender'] as String,
      meaning: json['meaning'] as String,
      origin: json['origin'] as String,
      root: json['root'] as String?,
      note: json['note'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arabic': arabic,
    'gender': gender,
    'meaning': meaning,
    'origin': origin,
    'root': root,
    'note': note,
  };

  IslamicName toEntity() => IslamicName(
    id: id,
    name: name,
    arabic: arabic,
    gender: gender,
    meaning: meaning,
    origin: origin,
    root: root,
    note: note,
  );
}
