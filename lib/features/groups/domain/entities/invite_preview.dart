/// What an invite link points at, shown before joining.
class InvitePreview {
  final String groupName;
  final String description;
  final int memberCount;

  /// True when the signed-in caller is already in the group. Only reported by
  /// the backend for authenticated requests; false for guests.
  final bool isMember;

  /// Present only when [isMember].
  final String? groupId;

  const InvitePreview({
    required this.groupName,
    this.description = '',
    required this.memberCount,
    this.isMember = false,
    this.groupId,
  });
}

/// Result of joining through an invite.
class JoinResult {
  final String groupId;

  /// True when the user was already in the group (joining is idempotent).
  final bool alreadyMember;

  const JoinResult({required this.groupId, required this.alreadyMember});
}
