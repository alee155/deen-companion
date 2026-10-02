import 'package:deen_companion/features/prayer_dnd/domain/dnd_settings.dart';
import 'package:deen_companion/features/prayer_dnd/domain/dnd_window_planner.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTimes _day(DateTime d) => PrayerTimes(
  fajr: DateTime(d.year, d.month, d.day, 5),
  dhuhr: DateTime(d.year, d.month, d.day, 12, 30),
  asr: DateTime(d.year, d.month, d.day, 16),
  maghrib: DateTime(d.year, d.month, d.day, 19),
  isha: DateTime(d.year, d.month, d.day, 20, 30),
  hijriDate: '',
);

void main() {
  final today = DateTime(2026, 9, 30);
  final days = [today, today.add(const Duration(days: 1))].map(_day).toList();
  final now = DateTime(2026, 9, 30, 12);

  test('each configured prayer gets its own duration', () {
    final w = DndWindowPlanner.build(
      days,
      const DndSettings(durations: {PrayerName.dhuhr: 20, PrayerName.isha: 30}),
      now,
    );
    final dhuhr = w.firstWhere((e) => e.prayerName == 'dhuhr');
    expect(dhuhr.end.difference(dhuhr.start), const Duration(minutes: 20));
    final isha = w.firstWhere((e) => e.prayerName == 'isha');
    expect(isha.end.difference(isha.start), const Duration(minutes: 30));
    expect(w.any((e) => e.prayerName == 'asr'), isFalse);
  });

  test('custom 5 minute window starts at the prayer and ends 5 min later', () {
    final w = DndWindowPlanner.build(
      days,
      const DndSettings(
        mode: DndDurationMode.custom,
        durations: {PrayerName.fajr: 5},
      ),
      now,
    );
    expect(w.single.start, DateTime(2026, 10, 1, 5));
    expect(w.single.end, DateTime(2026, 10, 1, 5, 5));
  });

  test('past prayers are skipped', () {
    final w = DndWindowPlanner.build(
      days,
      const DndSettings(durations: {PrayerName.fajr: 15}),
      now,
    );
    expect(w.every((e) => e.start.isAfter(now)), isTrue);
  });

  test('nothing configured yields no windows', () {
    expect(DndWindowPlanner.build(days, const DndSettings(), now), isEmpty);
  });

  test('duplicate days do not duplicate windows', () {
    final w = DndWindowPlanner.build(
      [...days, ...days],
      const DndSettings(durations: {PrayerName.isha: 10}),
      now,
    );
    expect(w.length, 2);
  });
}
