import 'package:flutter/material.dart';

import '../../../groups/domain/entities/group_detail.dart';
import '../../../groups/presentation/widgets/snap_widgets.dart';
import '../../domain/entities/leaderboard_entry.dart';

/// The member's picture, or their initials. The leaderboard carries no
/// pictures, so the link comes from the group's member list (when it has
/// loaded); until then, and for anyone without one, it is the initials.
class LeaderboardAvatar extends StatelessWidget {
  final LeaderboardEntry entry;
  final GroupDetail? group;
  final double size;
  final bool ring;

  const LeaderboardAvatar({
    super.key,
    required this.entry,
    required this.group,
    required this.size,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = group?.members
        .where((m) => m.userId == entry.userId)
        .map((m) => m.avatarUrl)
        .firstOrNull;
    return MemberAvatar(
      member: GroupMember(
        userId: entry.userId,
        name: entry.name,
        email: '',
        role: entry.role,
        avatarUrl: avatarUrl,
      ),
      size: size,
      ring: ring,
    );
  }
}
