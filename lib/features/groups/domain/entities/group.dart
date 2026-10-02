enum GroupPrivacy { public, private }

class Group {
  final String id;
  final String name;
  final String description;

  /// Asset path or local file path. Null falls back to an icon.
  final String? imagePath;
  final GroupPrivacy privacy;
  final int memberCount;
  final bool requiresApproval;

  /// True when the signed-in user created this group.
  final bool isOwner;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.privacy,
    required this.memberCount,
    this.imagePath,
    this.requiresApproval = false,
    this.isOwner = false,
  });

  bool get isPrivate => privacy == GroupPrivacy.private;
}

/// What the Create Group form submits.
class NewGroup {
  final String name;
  final String description;
  final GroupPrivacy privacy;
  final bool adminApproval;
  final String? imagePath;

  const NewGroup({
    required this.name,
    required this.description,
    required this.privacy,
    required this.adminApproval,
    this.imagePath,
  });
}
