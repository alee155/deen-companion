import 'package:equatable/equatable.dart';

import '../../groups/domain/entities/group.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import 'prayer_log.dart';

/// One member's row in the group feed (`GET /groups/{id}/prayers`): who they
/// are and what they logged on the requested prayer-day. The backend never
/// sends emails here.
class GroupMemberPrayers extends Equatable {
  final String userId;
  final String name;
  final GroupRole role;
  final List<PrayerLog> logs;

  const GroupMemberPrayers({
    required this.userId,
    required this.name,
    required this.role,
    required this.logs,
  });

  String get displayName => name.trim().isEmpty ? 'Member' : name.trim();

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  bool get isAdmin => role == GroupRole.admin;

  /// How many of the five prayers they have logged.
  int get loggedCount => logs.map((l) => l.prayer).toSet().length;

  int get totalPoints => logs.fold(0, (sum, l) => sum + l.points);

  /// The most recently logged prayer that has a snap (to open, opened or
  /// expired), or null. This is the snap other members see on this member's
  /// card.
  PrayerLog? latestSnapLog(DateTime now) {
    PrayerLog? latest;
    for (final l in logs) {
      if (l.snapState(now) == SnapState.none) continue;
      if (latest == null || l.loggedAt.isAfter(latest.loggedAt)) latest = l;
    }
    return latest;
  }

  PrayerLog? logFor(PrayerName prayer) {
    for (final l in logs) {
      if (l.prayer == prayer) return l;
    }
    return null;
  }

  @override
  List<Object?> get props => [userId, name, role, logs];
}
