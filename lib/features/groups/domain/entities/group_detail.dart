import 'group.dart';

/// A member as listed in `GET /groups/{id}`.
class GroupMember {
  final String userId;
  final String name;
  final String email;
  final GroupRole role;
  final DateTime? joinedAt;

  /// Signed link to the member's profile picture.
  final String? avatarUrl;

  const GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.joinedAt,
    this.avatarUrl,
  });

  bool get isAdmin => role == GroupRole.admin;

  String get displayName => name.trim().isEmpty ? email : name.trim();

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// Full group info including members. The signed-in user's own role isn't a
/// field here; it is read from [members] via [roleOf].
class GroupDetail {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final bool isInviteActive;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Signed link to the group picture, null when it has none.
  final String? avatarUrl;
  final List<GroupMember> members;

  const GroupDetail({
    required this.id,
    required this.name,
    this.description = '',
    this.inviteCode = '',
    this.isInviteActive = true,
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
    this.avatarUrl,
    this.members = const [],
  });

  int get memberCount => members.length;

  GroupRole roleOf(String? userId) {
    for (final m in members) {
      if (m.userId == userId) return m.role;
    }
    return GroupRole.member;
  }

  bool isAdmin(String? userId) => roleOf(userId) == GroupRole.admin;

  /// Applies the fields a PATCH can change, keeping members etc.
  GroupDetail withUpdate(Group updated) => GroupDetail(
    id: id,
    name: updated.name,
    description: updated.description,
    inviteCode: inviteCode,
    isInviteActive: isInviteActive,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updated.updatedAt ?? updatedAt,
    avatarUrl: updated.imagePath ?? avatarUrl,
    members: members,
  );

  GroupDetail withoutImage() => GroupDetail(
    id: id,
    name: name,
    description: description,
    inviteCode: inviteCode,
    isInviteActive: isInviteActive,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    members: members,
  );
}
