import 'package:equatable/equatable.dart';

import '../../prayer_logs/domain/current_prayer.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';

/// Why a snap can't be sent right now.
enum SnapUnavailableReason {
  /// Prayer times haven't been read yet.
  checking,

  /// No prayer window is open, so there is nothing a snap could log.
  noPrayerOpen,

  /// Every group that can have a snap for the open prayer already has one.
  allGroupsSent,

  /// None of the user's groups has anyone else in it, so a snap would reach
  /// nobody.
  noOtherMembers,

  /// Special days are on: the prayer is logged on her behalf, with no photo.
  specialDays,

  /// The user's prayer times were never synced, so the server can't say.
  timesNotSynced,

  /// The user isn't in any group to send to.
  noGroups,
}

/// Whether the user can send a snap right now, and if not, why.
///
/// A snap logs the prayer that is open (see `PrayerLogSnapRepository`), so
/// availability follows the server's answer to "which prayer is open and may a
/// photo be sent now" (`canSend`). A prayer can take several snaps, each for
/// the groups that have none yet. The reason is kept as data, not text, so
/// each screen words it for itself.
///
/// An *unknown* answer (the lookup failed, for instance offline) counts as
/// available: the server has the final say, and a failed lookup shouldn't take
/// the button away.
class SnapAvailability extends Equatable {
  final SnapUnavailableReason? reason;

  /// The open prayer, for the reasons that are about it.
  final PrayerName? loggedPrayer;

  /// The next prayer window, when the server knows it.
  final NextPrayer? next;

  const SnapAvailability._(this.reason, {this.loggedPrayer, this.next});

  const SnapAvailability.available() : this._(null);
  const SnapAvailability.checking() : this._(SnapUnavailableReason.checking);
  const SnapAvailability.noGroups() : this._(SnapUnavailableReason.noGroups);

  /// From the server's answer about the open prayer. [specialDays] is true
  /// while Special days are on, which can be a minute ahead of the server's
  /// own flag for the window that just opened.
  factory SnapAvailability.fromPrayer(
    CurrentPrayerState state, {
    bool specialDays = false,
  }) {
    final open = state.current;
    if (open != null) {
      SnapAvailability blocked(SnapUnavailableReason why) =>
          SnapAvailability._(why, loggedPrayer: open.prayer, next: state.next);
      if (specialDays || open.loggedWithoutPhoto) {
        return blocked(SnapUnavailableReason.specialDays);
      }
      if (open.canSend) return const SnapAvailability.available();
      return blocked(
        open.logged
            ? SnapUnavailableReason.allGroupsSent
            : SnapUnavailableReason.noOtherMembers,
      );
    }
    if (state.isNotSynced) {
      return const SnapAvailability._(SnapUnavailableReason.timesNotSynced);
    }
    return SnapAvailability._(
      SnapUnavailableReason.noPrayerOpen,
      next: state.next,
    );
  }

  bool get isAvailable => reason == null;

  @override
  List<Object?> get props => [reason, loggedPrayer, next];
}
