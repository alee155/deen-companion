import 'package:equatable/equatable.dart';

import '../../../prayer_times/domain/entities/prayer_times.dart';

/// The prayer with this server name (`fajr`…`isha`), or null for one the app
/// does not know.
PrayerName? prayerFromName(String? name) {
  for (final p in PrayerName.values) {
    if (p.name == name) return p;
  }
  return null;
}

/// The date range a statistic covers (both ends inclusive, `YYYY-MM-DD`).
class StatsRange extends Equatable {
  final String from;
  final String to;
  const StatsRange({required this.from, required this.to});

  @override
  List<Object?> get props => [from, to];
}

/// How far back the user is looking. The server allows up to 92 days and
/// defaults to 30.
enum StatsPeriod {
  week(7, 'Last 7 days'),
  month(30, 'Last 30 days'),
  quarter(90, 'Last 90 days');

  final int days;
  final String label;
  const StatsPeriod(this.days, this.label);

  String get short => '${days}d';

  /// The `from` date to send for "the last [days] days ending today", or null
  /// for the 30-day default (the server fills it in from the user's own
  /// timezone). `to` is never sent: the server's own "today" is the right end.
  String? fromDate(DateTime today) {
    if (this == StatsPeriod.month) return null;
    final d = DateTime(today.year, today.month, today.day - (days - 1));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

/// Counts over a period. A "perfect" day is one with all five prayers.
class PeriodTotals extends Equatable {
  final int prayersLogged;
  final int points;
  final int activeDays;
  final int perfectDays;

  const PeriodTotals({
    required this.prayersLogged,
    required this.points,
    required this.activeDays,
    required this.perfectDays,
  });

  @override
  List<Object?> get props => [prayersLogged, points, activeDays, perfectDays];
}

/// Logged prayers on completed days over the five a day that were possible.
/// [percent] is null until at least one day has completed.
class Completion extends Equatable {
  final double? percent;
  final int loggedPrayers;
  final int possiblePrayers;
  final int completedDays;

  const Completion({
    required this.percent,
    required this.loggedPrayers,
    required this.possiblePrayers,
    required this.completedDays,
  });

  @override
  List<Object?> get props => [
    percent,
    loggedPrayers,
    possiblePrayers,
    completedDays,
  ];
}

/// How one prayer did over a period. The streaks are only present on the
/// personal summary (they cover all history, whatever the range).
class PrayerStat extends Equatable {
  final PrayerName prayer;
  final int count;
  final double? percentOfCompletedDays;
  final int points;
  final int? currentStreak;
  final int? bestStreak;

  const PrayerStat({
    required this.prayer,
    required this.count,
    required this.percentOfCompletedDays,
    required this.points,
    this.currentStreak,
    this.bestStreak,
  });

  @override
  List<Object?> get props => [
    prayer,
    count,
    percentOfCompletedDays,
    points,
    currentStreak,
    bestStreak,
  ];
}

/// One day of a person's record, including days with nothing logged.
class DailyStat extends Equatable {
  /// `YYYY-MM-DD`.
  final String date;
  final int prayersLogged;
  final int points;
  final Map<PrayerName, bool> prayers;
  final bool isToday;

  const DailyStat({
    required this.date,
    required this.prayersLogged,
    required this.points,
    required this.prayers,
    required this.isToday,
  });

  DateTime get day => DateTime.parse(date);

  bool did(PrayerName p) => prayers[p] ?? false;

  @override
  List<Object?> get props => [date, prayersLogged, points, prayers, isToday];
}
