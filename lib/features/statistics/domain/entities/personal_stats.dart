import 'package:equatable/equatable.dart';

import '../../../prayer_times/domain/entities/prayer_times.dart';
import 'stats_common.dart';

/// `GET /users/me/stats/summary`: how the user did over a period.
class PersonalSummary extends Equatable {
  final StatsRange range;
  final PeriodTotals totals;
  final Completion completion;
  final List<PrayerStat> perPrayer;

  /// Null when nothing has been logged.
  final PrayerName? strongest;
  final PrayerName? weakest;

  const PersonalSummary({
    required this.range,
    required this.totals,
    required this.completion,
    required this.perPrayer,
    required this.strongest,
    required this.weakest,
  });

  PrayerStat? statFor(PrayerName p) {
    for (final s in perPrayer) {
      if (s.prayer == p) return s;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    range,
    totals,
    completion,
    perPrayer,
    strongest,
    weakest,
  ];
}

enum TrendGranularity {
  week('week', 'Weekly'),
  month('month', 'Monthly');

  final String apiValue;
  final String label;
  const TrendGranularity(this.apiValue, this.label);
}

/// One week or month of `GET /users/me/stats/trend`.
class TrendPoint extends Equatable {
  final String periodStart;
  final String periodEnd;
  final String label;
  final int prayersLogged;
  final int points;
  final int activeDays;
  final int perfectDays;

  /// Null when no day of the period has completed yet.
  final double? completionPercent;

  /// The running period, which is only partly over.
  final bool isCurrent;

  const TrendPoint({
    required this.periodStart,
    required this.periodEnd,
    required this.label,
    required this.prayersLogged,
    required this.points,
    required this.activeDays,
    required this.perfectDays,
    required this.completionPercent,
    required this.isCurrent,
  });

  @override
  List<Object?> get props => [
    periodStart,
    periodEnd,
    label,
    prayersLogged,
    points,
    activeDays,
    perfectDays,
    completionPercent,
    isCurrent,
  ];
}
