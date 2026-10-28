import 'package:equatable/equatable.dart';

import '../../prayer_logs/domain/current_prayer.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';

/// Why a snap can't be sent right now.
enum SnapUnavailableReason {
  /// Prayer times haven't been read yet.
  checking,

  /// No prayer window is open, so there is nothing a snap could log.
  noPrayerOpen,

  /// The open prayer already has its snap: one per prayer.
  alreadyLogged,

  /// The user's prayer times were never synced, so the server can't say.
  timesNotSynced,

  /// The user isn't in any group to send to.
  noGroups,
}

/// Whether the user can send a snap right now, and if not, why.
///
/// A snap logs the prayer that is open (see `PrayerLogSnapRepository`), so
/// availability follows the server's answer to "which prayer is open". The
/// reason is kept as data, not text, so each screen words it for itself.
///
/// An *unknown* answer (the lookup failed, for instance offline) counts as
/// available: the server has the final say, and a failed lookup shouldn't take
/// the button away.
class SnapAvailability extends Equatable {
  final SnapUnavailableReason? reason;

  /// The prayer that already has its snap, for [SnapUnavailableReason.alreadyLogged].
  final PrayerName? loggedPrayer;

  /// The next prayer window, when the server knows it.
  final NextPrayer? next;

  const SnapAvailability._(this.reason, {this.loggedPrayer, this.next});

  const SnapAvailability.available() : this._(null);
  const SnapAvailability.checking() : this._(SnapUnavailableReason.checking);
  const SnapAvailability.noGroups() : this._(SnapUnavailableReason.noGroups);

  /// From the server's answer about the open prayer.
  factory SnapAvailability.fromPrayer(CurrentPrayerState state) {
    final open = state.current;
    if (open != null && !open.logged) return const SnapAvailability.available();
    if (open != null) {
      return SnapAvailability._(
        SnapUnavailableReason.alreadyLogged,
        loggedPrayer: open.prayer,
        next: state.next,
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
