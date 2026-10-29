import 'package:intl/intl.dart';

import '../../../core/error/failures.dart';
import '../domain/special_days.dart';
import '../domain/special_days_failure.dart';

/// "8 Nov" for a local date like `2026-11-08`; null if it can't be read.
String? shortLocalDate(String? yyyyMmDd) {
  final d = yyyyMmDd == null ? null : DateTime.tryParse(yyyyMmDd);
  return d == null ? null : DateFormat('d MMM').format(d);
}

/// "13 Nov" for an instant, in the phone's own zone.
String shortDate(DateTime instant) =>
    DateFormat('d MMM').format(instant.toLocal());

/// "2 days left", "1 day left", or "Ends today".
String daysLeftText(int? days) {
  if (days == null) return '';
  if (days <= 0) return 'Ends today';
  return days == 1 ? '1 day left' : '$days days left';
}

/// What to tell the user about a failed special-days call, in plain words.
/// [state] is the account as the server last said (for the date in "too soon").
String specialDaysMessage(Failure failure, {SpecialDays? state}) {
  if (failure is! SpecialDaysFailure) return failure.message;
  switch (failure.code) {
    case SpecialDaysErrorCode.tooSoon:
      final at = state?.canStartAt;
      return at == null
          ? 'You can start special days again a little later.'
          : 'You can start special days again on ${shortDate(at)}.';
    case SpecialDaysErrorCode.timesNotSynced:
      return 'Your prayer times aren’t set up yet. Open Prayer Times to set '
          'your location, then try again.';
    case SpecialDaysErrorCode.imageDuplicate:
      return 'Each prayer needs a different photo. Choose another one.';
    case SpecialDaysErrorCode.active:
      return 'Photos can’t be changed while special days are on.';
    case SpecialDaysErrorCode.alreadyActive:
      return 'Special days are already on.';
    case SpecialDaysErrorCode.notAvailable:
      return 'Special days aren’t available for this account.';
    case SpecialDaysErrorCode.imagesRequired:
    case SpecialDaysErrorCode.fileTooLarge:
    case SpecialDaysErrorCode.other:
      return failure.message;
  }
}
