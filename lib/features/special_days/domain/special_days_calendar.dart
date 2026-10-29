import 'package:equatable/equatable.dart';

import 'special_days.dart';

/// Where a day of the period stands.
enum SpecialDayPhase { past, today, upcoming }

/// One local day of the running period.
class SpecialDayCell extends Equatable {
  /// 1-based: "day 3 of 10".
  final int number;

  /// The calendar date (no time of day).
  final DateTime date;
  final SpecialDayPhase phase;

  const SpecialDayCell({
    required this.number,
    required this.date,
    required this.phase,
  });

  /// `yyyy-MM-dd`, the form the prayer-log endpoints use.
  String get key =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [number, date, phase];
}

/// The days of a running period, for the calendar under the switch.
///
/// The server says the first local day ([SpecialDays.startLocalDate]) and the
/// day the period ends ([SpecialDays.endsLocalDate], midnight at the start of
/// it, so it is the first day *after* the period) and how many days remain
/// including today. From those: the days, and which one is today, without
/// trusting the phone's clock.
class SpecialDaysCalendar extends Equatable {
  final List<SpecialDayCell> days;

  /// Index of today in [days].
  final int todayIndex;

  const SpecialDaysCalendar({required this.days, required this.todayIndex});

  int get total => days.length;

  /// "Day 3 of 10".
  int get todayNumber => todayIndex + 1;

  int get daysLeftIncludingToday => total - todayIndex;

  String get firstKey => days.first.key;
  String get lastKey => days.last.key;

  /// The last day for which logs can exist: today.
  String get todayKey => days[todayIndex].key;

  /// Null unless special days are running and the dates make sense.
  static SpecialDaysCalendar? of(SpecialDays state, {DateTime? now}) {
    if (!state.active) return null;
    final start = _date(state.startLocalDate);
    final end = _date(state.endsLocalDate);
    if (start == null || end == null) return null;
    final total = end.difference(start).inDays;
    if (total < 1 || total > 31) return null;

    final left = state.daysRemaining;
    int today;
    if (left != null) {
      today = total - left;
    } else {
      final n = now ?? DateTime.now();
      today = DateTime(n.year, n.month, n.day).difference(start).inDays;
    }
    today = today.clamp(0, total - 1);

    return SpecialDaysCalendar(
      todayIndex: today,
      days: [
        for (var i = 0; i < total; i++)
          SpecialDayCell(
            number: i + 1,
            // Calendar arithmetic, not +24h, so a clock change can't skip one.
            date: DateTime(start.year, start.month, start.day + i),
            phase: i < today
                ? SpecialDayPhase.past
                : i == today
                ? SpecialDayPhase.today
                : SpecialDayPhase.upcoming,
          ),
      ],
    );
  }

  static DateTime? _date(String? yyyyMmDd) {
    final d = yyyyMmDd == null ? null : DateTime.tryParse(yyyyMmDd);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  @override
  List<Object?> get props => [days, todayIndex];
}
