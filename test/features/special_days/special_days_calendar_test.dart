import 'package:deen_companion/features/special_days/domain/special_days.dart';
import 'package:deen_companion/features/special_days/domain/special_days_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

SpecialDays _running({
  String? start = '2026-10-29',
  String? end = '2026-11-08',
  int? left = 10,
  bool active = true,
}) => SpecialDays(
  eligible: true,
  active: active,
  startLocalDate: start,
  endsLocalDate: end,
  daysRemaining: left,
);

void main() {
  test('the period is the ten days up to (not including) the end date', () {
    final c = SpecialDaysCalendar.of(_running())!;
    expect(c.total, 10);
    expect(c.days.first.date, DateTime(2026, 10, 29));
    expect(c.days.last.date, DateTime(2026, 11, 7));
    expect(c.firstKey, '2026-10-29');
    expect(c.lastKey, '2026-11-07');
    expect([for (final d in c.days) d.number], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  test('today comes from the server\'s days remaining', () {
    final first = SpecialDaysCalendar.of(_running(left: 10))!;
    expect(first.todayIndex, 0);
    expect(first.todayNumber, 1);
    expect(first.todayKey, '2026-10-29');
    expect(first.daysLeftIncludingToday, 10);

    final mid = SpecialDaysCalendar.of(_running(left: 7))!;
    expect(mid.todayNumber, 4);
    expect(mid.todayKey, '2026-11-01');
    expect(
      [for (final d in mid.days) d.phase],
      [
        ...List.filled(3, SpecialDayPhase.past),
        SpecialDayPhase.today,
        ...List.filled(6, SpecialDayPhase.upcoming),
      ],
    );

    final last = SpecialDaysCalendar.of(_running(left: 1))!;
    expect(last.todayNumber, 10);
    expect(last.daysLeftIncludingToday, 1);
  });

  test('without days remaining, the clock decides', () {
    final c = SpecialDaysCalendar.of(
      _running(left: null),
      now: DateTime(2026, 11, 2, 15),
    )!;
    expect(c.todayNumber, 5);
  });

  test('a stale or odd count can not point outside the period', () {
    expect(SpecialDaysCalendar.of(_running(left: 0))!.todayNumber, 10);
    expect(SpecialDaysCalendar.of(_running(left: 99))!.todayNumber, 1);
  });

  test('days are calendar days even across a month and clock change', () {
    final c = SpecialDaysCalendar.of(
      _running(start: '2026-10-28', end: '2026-11-07', left: 10),
    )!;
    expect(c.days[3].date, DateTime(2026, 10, 31));
    expect(c.days[4].date, DateTime(2026, 11, 1));
    expect(c.days.map((d) => d.key).toSet().length, 10);
  });

  test('nothing to show unless it is running with readable dates', () {
    expect(SpecialDaysCalendar.of(_running(active: false)), isNull);
    expect(SpecialDaysCalendar.of(_running(start: null)), isNull);
    expect(SpecialDaysCalendar.of(_running(end: 'nonsense')), isNull);
    expect(
      SpecialDaysCalendar.of(_running(start: '2026-11-08', end: '2026-11-08')),
      isNull,
    );
  });
}
