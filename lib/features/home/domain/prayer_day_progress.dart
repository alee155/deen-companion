import 'package:equatable/equatable.dart';

import '../../prayer_times/domain/entities/prayer_times.dart';

/// What the Home header shows about the prayer coming up at one moment. Pure
/// data derived from [PrayerTimes], so it is easy to test.
class PrayerDayProgress extends Equatable {
  final PrayerName next;
  final DateTime nextAt;

  /// How long until [next].
  final Duration remaining;

  const PrayerDayProgress({
    required this.next,
    required this.nextAt,
    required this.remaining,
  });

  /// Within this long of the next prayer the header draws attention to it.
  static const imminent = Duration(minutes: 10);

  bool get isImminent => remaining <= imminent;

  factory PrayerDayProgress.of(PrayerTimes times, DateTime now) {
    final next = times.nextPrayer(now);
    return PrayerDayProgress(
      next: next.key,
      nextAt: next.value,
      remaining: next.value.difference(now),
    );
  }

  @override
  List<Object?> get props => [next, nextAt, remaining];
}
