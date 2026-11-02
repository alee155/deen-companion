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

  /// Groups that already have a photo for this prayer.
  final List<String> sentGroupIds;

  /// Groups that can still be sent a photo now. Never lists a group where you
  /// are the only member, so it is the list to offer in the group picker.
  final List<String> unsentGroupIds;

  /// The server's answer to "may a photo be sent now": the camera follows it.
  /// False once every group has its photo, when there is no group with
  /// someone else in it, and while Special days log the prayer for her.
  final bool canSend;

  const CurrentPrayer({
    required this.prayer,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.logged,
    required this.logId,
    this.sentGroupIds = const [],
    this.unsentGroupIds = const [],
    this.canSend = true,
  });

  /// Logged, and every group that can have a photo has one.
  bool get allSent =>
      logged && sentGroupIds.isNotEmpty && unsentGroupIds.isEmpty;

  /// Logged with no photo sent: the log Special days make on her behalf.
  bool get loggedWithoutPhoto => logged && sentGroupIds.isEmpty;

  @override
  List<Object?> get props => [
    prayer,
    date,
    startsAt,
    endsAt,
    logged,
    logId,
    sentGroupIds,
    unsentGroupIds,
    canSend,
  ];
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
