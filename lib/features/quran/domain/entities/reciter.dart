import 'package:equatable/equatable.dart';

class Reciter extends Equatable {
  final int id;
  final String name;
  final String style;

  const Reciter({required this.id, required this.name, required this.style});

  @override
  List<Object?> get props => [id, name, style];
}
