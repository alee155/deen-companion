import '../../domain/entities/group.dart';
import '../../domain/entities/group_detail.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/entities/invite_preview.dart';

/// One group as returned by `GET /groups` (has `role`) or `POST /groups`
/// (no `role` — the creator is always the admin).
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final bool isInviteActive;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? role;

  /// Signed link to the group picture, null when it has none.
  final String? avatarUrl;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.isInviteActive,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.role,
    this.avatarUrl,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    inviteCode: json['inviteCode'] as String? ?? '',
    isInviteActive: json['isInviteActive'] as bool? ?? true,
    createdBy: json['createdBy'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    role: json['role'] as String?,
    avatarUrl: _url(json['avatarUrl']),
  );

  Group toEntity({GroupRole? fallbackRole}) => Group(
    id: id,
    name: name,
    description: description ?? '',
    inviteCode: inviteCode,
    isInviteActive: isInviteActive,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    imagePath: avatarUrl,
    role: role == null
        ? (fallbackRole ?? GroupRole.member)
        : GroupRole.parse(role),
  );
}

String? _url(Object? v) {
  final s = v is String ? v.trim() : null;
  return s == null || s.isEmpty ? null : s;
}

class GroupMemberModel {
  final String userId;
  final String name;
  final String email;
  final String? role;
  final DateTime? joinedAt;
  final String? avatarUrl;

  const GroupMemberModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.avatarUrl,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) =>
      GroupMemberModel(
        userId: json['userId'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String?,
        joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? ''),
        avatarUrl: _url(json['avatarUrl']),
      );

  GroupMember toEntity() => GroupMember(
    userId: userId,
    name: name,
    email: email,
    role: GroupRole.parse(role),
    joinedAt: joinedAt,
    avatarUrl: avatarUrl,
  );
}

/// `data` of `GET /groups/{id}`.
class GroupDetailModel {
  final GroupModel group;
  final List<GroupMemberModel> members;

  const GroupDetailModel({required this.group, required this.members});

  factory GroupDetailModel.fromJson(Map<String, dynamic> json) =>
      GroupDetailModel(
        group: GroupModel.fromJson(json),
        members: [
          for (final m in (json['members'] as List? ?? const []))
            GroupMemberModel.fromJson(m as Map<String, dynamic>),
        ],
      );

  GroupDetail toEntity() => GroupDetail(
    id: group.id,
    name: group.name,
    description: group.description ?? '',
    inviteCode: group.inviteCode,
    isInviteActive: group.isInviteActive,
    createdBy: group.createdBy,
    createdAt: group.createdAt,
    updatedAt: group.updatedAt,
    avatarUrl: group.avatarUrl,
    members: [for (final m in members) m.toEntity()],
  );
}

/// `data` of `GET /groups/{id}/invite` and `POST /groups/{id}/invite/reset`.
class GroupInviteModel {
  final String token;
  final String url;

  const GroupInviteModel({required this.token, required this.url});

  factory GroupInviteModel.fromJson(Map<String, dynamic> json) =>
      GroupInviteModel(
        token: json['token'] as String,
        url: json['url'] as String,
      );

  GroupInvite toEntity() => GroupInvite(token: token, url: url);
}

/// `data` of `GET /invites/{token}`.
class InvitePreviewModel {
  final String groupName;
  final String? description;
  final int memberCount;
  final bool isMember;
  final String? groupId;

  const InvitePreviewModel({
    required this.groupName,
    required this.description,
    required this.memberCount,
    required this.isMember,
    required this.groupId,
  });

  factory InvitePreviewModel.fromJson(Map<String, dynamic> json) =>
      InvitePreviewModel(
        groupName: json['groupName'] as String,
        description: json['description'] as String?,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        isMember: json['isMember'] as bool? ?? false,
        groupId: json['groupId'] as String?,
      );

  InvitePreview toEntity() => InvitePreview(
    groupName: groupName,
    description: description ?? '',
    memberCount: memberCount,
    isMember: isMember,
    groupId: groupId,
  );
}

/// `data` of `POST /invites/{token}/join`.
class JoinResultModel {
  final String groupId;
  final bool alreadyMember;

  const JoinResultModel({required this.groupId, required this.alreadyMember});

  factory JoinResultModel.fromJson(Map<String, dynamic> json) =>
      JoinResultModel(
        groupId: json['groupId'] as String,
        alreadyMember: json['alreadyMember'] as bool? ?? false,
      );

  JoinResult toEntity() =>
      JoinResult(groupId: groupId, alreadyMember: alreadyMember);
}
