import '../../domain/entities/user_profile.dart';

/// The profile body is not documented in the API spec, so the keys below are
/// the likely ones; [avatarUrl] also accepts `photoUrl`/`avatar`.
UserProfile userProfileFromJson(Map<String, dynamic> json) {
  // Some responses wrap the account in `user`.
  final j = json['user'] is Map<String, dynamic>
      ? json['user'] as Map<String, dynamic>
      : json;
  String? text(Object? v) {
    final s = v is String ? v.trim() : null;
    return s == null || s.isEmpty ? null : s;
  }

  return UserProfile(
    id: j['id'] as String,
    name: text(j['name']) ?? '',
    email: text(j['email']) ?? '',
    avatarUrl: text(j['avatarUrl']) ?? text(j['photoUrl']) ?? text(j['avatar']),
    timezone: text(j['timezone']),
  );
}

UserPoints userPointsFromJson(Map<String, dynamic> json) => UserPoints(
  total: json['total'] as num? ?? 0,
  groups: [
    for (final g in (json['groups'] as List? ?? const []))
      GroupPoints(
        groupId: (g as Map<String, dynamic>)['groupId'] as String,
        name: g['name'] as String? ?? '',
        points: g['points'] as num? ?? 0,
      ),
  ],
);
