import '../../../auth/domain/entities/gender.dart';

/// The signed-in account as `GET /users/me` returns it.
class UserProfile {
  final String id;
  final String name;
  final String email;

  /// A signed link: it expires, so it is never stored for long. Null when the
  /// user has no picture.
  final String? avatarUrl;

  /// IANA name the server has stored for the account.
  final String? timezone;

  /// Null until set: accounts made before the field existed are asked once.
  /// Once set it never changes.
  final Gender? gender;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.timezone,
    this.gender,
  });
}

/// `GET /users/me/points`: all-time total plus what was earned in each group
/// since the user joined it.
class UserPoints {
  final num total;
  final List<GroupPoints> groups;

  const UserPoints({required this.total, required this.groups});

  static const empty = UserPoints(total: 0, groups: []);
}

class GroupPoints {
  final String groupId;
  final String name;
  final num points;

  const GroupPoints({
    required this.groupId,
    required this.name,
    required this.points,
  });
}
