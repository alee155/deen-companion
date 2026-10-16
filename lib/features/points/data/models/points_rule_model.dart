import '../../domain/entities/points_rule.dart';

/// One entry of `GET /points/rules`: `{ "prayer": "fajr", "points": 10 }`.
class PointsRuleModel {
  final String prayer;
  final int points;

  const PointsRuleModel({required this.prayer, required this.points});

  factory PointsRuleModel.fromJson(Map<String, dynamic> json) =>
      PointsRuleModel(
        prayer: json['prayer'] as String,
        points: (json['points'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'prayer': prayer, 'points': points};

  PointsRule toEntity() => PointsRule(prayer: prayer, points: points);
}

/// The whole table, as saved in the local cache.
class PointsRulesModel {
  final List<PointsRuleModel> rules;
  const PointsRulesModel(this.rules);

  factory PointsRulesModel.fromList(List<dynamic> list) => PointsRulesModel([
    for (final e in list) PointsRuleModel.fromJson(e as Map<String, dynamic>),
  ]);

  factory PointsRulesModel.fromJson(Map<String, dynamic> json) =>
      PointsRulesModel.fromList(json['rules'] as List<dynamic>);

  Map<String, dynamic> toJson() => {
    'rules': [for (final r in rules) r.toJson()],
  };

  PointsRules toEntity() => PointsRules([for (final r in rules) r.toEntity()]);
}
