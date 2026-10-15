import 'package:equatable/equatable.dart';

import '../../prayer_times/domain/entities/prayer_times.dart';

/// The prayer whose window is open right now.
class CurrentPrayer extends Equatable {
  final PrayerName prayer;

  /// Prayer-day date — at 1 AM an open Isha still belongs to yesterday.
  final String date;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool logged;

  /// Set when [logged]; what Undo deletes.
  final String? logId;

  const CurrentPrayer({
    required this.prayer,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.logged,
    required this.logId,
  });

  @override
  List<Object?> get props => [prayer, date, startsAt, endsAt, logged, logId];
}

class NextPrayer extends Equatable {
  final PrayerName prayer;
  final DateTime startsAt;
  const NextPrayer({required this.prayer, required this.startsAt});

  @override
  List<Object?> get props => [prayer, startsAt];
}

/// `GET /prayers/current`, computed on the server's clock.
///
/// [current] set and not logged → Log button; set and logged → checkmark
/// (+ Undo while allowed); null → button disabled, show [next].
class CurrentPrayerState extends Equatable {
  final DateTime now;
  final CurrentPrayer? current;
  final NextPrayer? next;

  const CurrentPrayerState({required this.now, this.current, this.next});

  /// Both null means this user's times were never synced.
  bool get isNotSynced => current == null && next == null;

  @override
  List<Object?> get props => [now, current, next];
}
