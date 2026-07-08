import '../../domain/entities/asma_daily.dart';
import 'asma_name_model.dart';

class AsmaDailyModel {
  final int dayNumber;
  final String dayName;
  final List<AsmaNameModel> names;
  final int count;
  final String suggestion;
  final String weeklyCompletion;

  const AsmaDailyModel({
    required this.dayNumber,
    required this.dayName,
    required this.names,
    required this.count,
    required this.suggestion,
    required this.weeklyCompletion,
  });

  factory AsmaDailyModel.fromJson(Map<String, dynamic> json) {
    return AsmaDailyModel(
      dayNumber: json['day_number'] as int,
      dayName: json['day_name'] as String,
      names: (json['names'] as List)
          .map((e) => AsmaNameModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int,
      suggestion: json['suggestion'] as String,
      weeklyCompletion: json['weekly_completion'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'day_number': dayNumber,
    'day_name': dayName,
    'names': names.map((n) => n.toJson()).toList(),
    'count': count,
    'suggestion': suggestion,
    'weekly_completion': weeklyCompletion,
  };

  AsmaDaily toEntity() => AsmaDaily(
    dayNumber: dayNumber,
    dayName: dayName,
    names: names.map((n) => n.toEntity()).toList(),
    count: count,
    suggestion: suggestion,
    weeklyCompletion: weeklyCompletion,
  );
}
