enum GroupPrivacy { public, private }

/// The signed-in user's role in a group, as reported by `GET /groups`.
/// Unrecognised values from the backend fall back to [member] so a new role
/// never breaks parsing.
enum GroupRole {
  admin,
  member;

  static GroupRole parse(String? raw) => switch (raw) {
    'admin' => GroupRole.admin,
    _ => GroupRole.member,
  };
}

class Group {
  final String id;
  final String name;
  final String description;

  /// Code others use to join. Not shown in the UI yet.
  final String inviteCode;
  final bool isInviteActive;

  /// User id of the creator.
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GroupRole role;

  /// The group's picture: the server's signed `avatarUrl`, or an asset or
  /// local file path. Null falls back to an icon.
  final String? imagePath;

  // The API doesn't report these yet; the existing card UI still renders
  // them, so they carry neutral defaults until the backend does.

  final GroupPrivacy privacy;
  final int memberCount;
  final bool requiresApproval;

  const Group({
    required this.id,
    required this.name,
    this.description = '',
    this.inviteCode = '',
    this.isInviteActive = true,
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
    this.role = GroupRole.member,
    this.imagePath,
    this.privacy = GroupPrivacy.private,
    this.memberCount = 1,
    this.requiresApproval = false,
  });

  bool get isPrivate => privacy == GroupPrivacy.private;

  /// True when the signed-in user administers (created) this group.
  bool get isOwner => role == GroupRole.admin;

  /// Applies the fields a PATCH can change (name/description/updatedAt),
  /// keeping this user's role and the list-only fields.
  Group withUpdate(Group updated) => Group(
    id: id,
    name: updated.name,
    description: updated.description,
    inviteCode: inviteCode,
    isInviteActive: isInviteActive,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updated.updatedAt ?? updatedAt,
    role: role,
    imagePath: updated.imagePath ?? imagePath,
    privacy: privacy,
    memberCount: memberCount,
    requiresApproval: requiresApproval,
  );

  /// This group after its picture was removed.
  Group withoutImage() => Group(
    id: id,
    name: name,
    description: description,
    inviteCode: inviteCode,
    isInviteActive: isInviteActive,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    role: role,
    privacy: privacy,
    memberCount: memberCount,
    requiresApproval: requiresApproval,
  );

  Group copyWith({GroupRole? role}) => Group(
    id: id,
    name: name,
    description: description,
    inviteCode: inviteCode,
    isInviteActive: isInviteActive,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    role: role ?? this.role,
    imagePath: imagePath,
    privacy: privacy,
    memberCount: memberCount,
    requiresApproval: requiresApproval,
  );
}

/// What the Create Group form collects. [name], [description] and the
/// picture at [imagePath] are sent to the API; the rest is kept so the form can grow without
/// reshaping the domain.
class NewGroup {
  final String name;
  final String description;
  final GroupPrivacy privacy;
  final bool adminApproval;
  final String? imagePath;

  const NewGroup({
    required this.name,
    required this.description,
    this.privacy = GroupPrivacy.public,
    this.adminApproval = false,
    this.imagePath,
  });
}
