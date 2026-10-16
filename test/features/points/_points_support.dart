import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/points/domain/entities/points_rule.dart';
import 'package:deen_companion/features/points/domain/repositories/points_repository.dart';

/// The response the backend returned for `GET /points/rules`.
const sampleRulesJson = [
  {'prayer': 'fajr', 'points': 10},
  {'prayer': 'dhuhr', 'points': 5},
  {'prayer': 'asr', 'points': 5},
  {'prayer': 'maghrib', 'points': 5},
  {'prayer': 'isha', 'points': 5},
];

PointsRules sampleRules() => PointsRules([
  const PointsRule(prayer: 'fajr', points: 10),
  const PointsRule(prayer: 'dhuhr', points: 5),
  const PointsRule(prayer: 'asr', points: 5),
  const PointsRule(prayer: 'maghrib', points: 5),
  const PointsRule(prayer: 'isha', points: 5),
]);

/// In-memory repository whose answers a test sets.
class FakePointsRepo implements PointsRepository {
  PointsRules? cached;
  Result<PointsRules> result = const Error(NetworkFailure());
  int fetches = 0;

  @override
  PointsRules? getCachedRules() => cached;

  @override
  Future<Result<PointsRules>> fetchRules() async {
    fetches++;
    return result;
  }
}
