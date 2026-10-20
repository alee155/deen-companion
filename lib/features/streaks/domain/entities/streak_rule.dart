import 'package:equatable/equatable.dart';

/// What a group asks of its members each day to keep a streak: log at least
/// [minPrayers] distinct prayers. The admin chooses it; the default is 1.
class StreakRule extends Equatable {
  /// The fewest and most prayers a rule can ask for (the server rejects
  /// anything outside this range).
  static const minAllowed = 1;
  static const maxAllowed = 5;

  final int minPrayers;

  /// When this rule came into force. A change made on day D applies from the
  /// next day in each member's own timezone, so this can be ahead of "today"
  /// for a member.
  final DateTime effectiveFrom;

  const StreakRule({required this.minPrayers, required this.effectiveFrom});

  /// The requirement when a group has never set one.
  static final standard = StreakRule(
    minPrayers: minAllowed,
    effectiveFrom: DateTime.utc(1970),
  );

  /// "Log at least 3 prayers a day".
  String get summary => minPrayers == 1
      ? 'Log at least 1 prayer a day'
      : minPrayers == maxAllowed
      ? 'Log all $maxAllowed prayers every day'
      : 'Log at least $minPrayers prayers a day';

  @override
  List<Object?> get props => [minPrayers, effectiveFrom];
}
