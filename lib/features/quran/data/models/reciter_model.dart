import '../../domain/entities/reciter.dart';

class ReciterModel {
  final int id;
  final String name;
  final String style;

  const ReciterModel({
    required this.id,
    required this.name,
    required this.style,
  });

  factory ReciterModel.fromJson(Map<String, dynamic> json) {
    return ReciterModel(
      id: json['id'] as int,
      name: json['name'] as String,
      style: json['style'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'style': style};

  Reciter toEntity() => Reciter(id: id, name: name, style: style);
}
