import 'package:flutter/material.dart' show IconData, Icons;
import 'package:intl/intl.dart';

import '../../../core/error/failures.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import '../domain/prayer_log_failure.dart';

extension PrayerNameLabel on PrayerName {
  String get label => switch (this) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };

  /// The sky icon used for this prayer across the app.
  IconData get icon => switch (this) {
    PrayerName.fajr => Icons.wb_twilight_rounded,
    PrayerName.dhuhr => Icons.wb_sunny_rounded,
    PrayerName.asr => Icons.wb_sunny_outlined,
    PrayerName.maghrib => Icons.nights_stay_rounded,
    PrayerName.isha => Icons.dark_mode_rounded,
  };
}

/// `5:25 PM` in the device's timezone.
String clockTime(DateTime t) => DateFormat('h:mm a').format(t.toLocal());

/// `1h 55m`, `42m`, `<1m`.
String countdown(Duration d) {
  if (d.inMinutes < 1) return '<1m';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h == 0 ? '${m}m' : '${h}h ${m}m';
}

/// What to tell the user for a failed prayer-log call. Specific codes get
/// specific wording; anything else shows the server's own message.
String prayerLogErrorMessage(Failure failure) {
  if (failure is! PrayerLogFailure) return failure.message;
  switch (failure.code) {
    case PrayerLogErrorCode.noActiveWindow:
      final next = failure.nextPrayer;
      final at = failure.nextStartsAt;
      return next != null && at != null
          ? 'No prayer is open right now. ${next.label} starts at '
                '${clockTime(at)}.'
          : 'No prayer is open right now.';
    case PrayerLogErrorCode.alreadyLogged:
      return 'You’ve already logged this prayer.';
    case PrayerLogErrorCode.timesNotSynced:
      return 'Your prayer times aren’t set up yet. Try again in a moment.';
    case PrayerLogErrorCode.undoLocked:
      return 'This prayer’s time has ended, so it can’t be removed.';
    case PrayerLogErrorCode.notGroupMember:
      return 'Only members of this group can see this.';
    case PrayerLogErrorCode.dayLocked:
    case PrayerLogErrorCode.fileTooLarge:
    case PrayerLogErrorCode.other:
      return failure.message;
  }
}
