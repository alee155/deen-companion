import '../../domain/entities/islamic_month.dart';

class IslamicMonthModel {
  final int number;
  final String nameEnglish;
  final String nameArabic;
  final String significance;

  const IslamicMonthModel({
    required this.number,
    required this.nameEnglish,
    required this.nameArabic,
    required this.significance,
  });

  factory IslamicMonthModel.fromJson(Map<String, dynamic> json) {
    return IslamicMonthModel(
      number: json['number'] as int,
      nameEnglish: json['name_english'] as String,
      nameArabic: json['name_arabic'] as String,
      significance: json['significance'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name_english': nameEnglish,
    'name_arabic': nameArabic,
    'significance': significance,
  };

  IslamicMonth toEntity() => IslamicMonth(
    number: number,
    nameEnglish: nameEnglish,
    nameArabic: nameArabic,
    significance: significance,
  );
}
