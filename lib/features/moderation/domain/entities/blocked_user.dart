import 'package:equatable/equatable.dart';

/// Someone the signed-in user has blocked. Carries the name and picture so the
/// "Blocked users" list can show who it is without looking the person up.
class BlockedUser extends Equatable {
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.userId,
    required this.name,
    required this.blockedAt,
    this.avatarUrl,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  Map<String, Object?> toJson() => {
    'userId': userId,
    'name': name,
    'avatarUrl': avatarUrl,
    'blockedAt': blockedAt.toIso8601String(),
  };

  /// Null when [json] isn't a usable record (older or damaged data is skipped,
  /// never fatal).
  static BlockedUser? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['userId'];
    if (id is! String || id.isEmpty) return null;
    final name = json['name'];
    final at = json['blockedAt'];
    return BlockedUser(
      userId: id,
      name: name is String ? name : '',
      avatarUrl: json['avatarUrl'] is String
          ? json['avatarUrl'] as String
          : null,
      blockedAt:
          (at is String ? DateTime.tryParse(at) : null) ?? DateTime(1970),
    );
  }

  @override
  List<Object?> get props => [userId, name, avatarUrl, blockedAt];
}
