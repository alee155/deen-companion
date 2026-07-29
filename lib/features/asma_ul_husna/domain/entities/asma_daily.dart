import 'asma_name.dart';

class AsmaDaily {
  final int dayNumber;
  final String dayName;
  final List<AsmaName> names;
  final int count;
  final String suggestion;
  final String weeklyCompletion;

  const AsmaDaily({
    required this.dayNumber,
    required this.dayName,
    required this.names,
    required this.count,
    required this.suggestion,
    required this.weeklyCompletion,
  });
}
