import '../../prayer_logs/presentation/prayer_labels.dart';
import '../domain/snap_availability.dart';

/// What to tell the user when a snap can't be sent: the reason, in a full
/// sentence, and when it will be possible if that is known.
extension SnapAvailabilityMessage on SnapAvailability {
  /// Null while a snap can be sent.
  String? get message {
    final reason = this.reason;
    if (reason == null) return null;
    final nextLine = next == null
        ? null
        : '${next!.prayer.label} starts at ${clockTime(next!.startsAt)}.';
    return switch (reason) {
      SnapUnavailableReason.checking =>
        'Checking your prayer times… try again in a moment.',
      SnapUnavailableReason.noPrayerOpen => [
        'Snaps can only be sent while a prayer time is open.',
        ?nextLine,
      ].join(' '),
      SnapUnavailableReason.allGroupsSent => [
        'You’ve sent your ${loggedPrayer?.label ?? 'prayer'} snap to all '
            'your groups.',
        ?nextLine,
      ].join(' '),
      SnapUnavailableReason.noOtherMembers =>
        'None of your groups has anyone else in it yet, so there’s nobody to '
            'send a snap to. Invite someone to a group first.',
      SnapUnavailableReason.specialDays => [
        'Special days are on, so your ${loggedPrayer?.label ?? 'prayer'} is '
            'logged for you and there’s nothing to send.',
        ?nextLine,
      ].join(' '),
      SnapUnavailableReason.timesNotSynced =>
        'Your prayer times aren’t set up yet, so we can’t tell when snaps '
            'are open. Open Prayer Times to set your location.',
      SnapUnavailableReason.noGroups =>
        'Join or create a group to start sending snaps.',
    };
  }
}
