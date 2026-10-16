import '../../../../core/usecase/usecase.dart';
import '../entities/points_rule.dart';

abstract class PointsRepository {
  /// The last rule table fetched, readable synchronously for cache-first
  /// screens. Null until a first successful fetch.
  PointsRules? getCachedRules();

  /// `GET /points/rules` — the points each prayer earns. Open to every signed-in
  /// user (admins and members alike). Caches the result.
  Future<Result<PointsRules>> fetchRules();
}
