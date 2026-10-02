/// Result of a successful auth action. Minimal on purpose — the real shape
/// (tokens, etc.) depends on the backend that will be wired in later; this is
/// enough for the presentation layer to know who is signed in, or that the
/// user is browsing as a guest.
class AuthSession {
  final String? userId;
  final String? email;
  final String? name;
  final String? photoUrl;
  final bool isGuest;

  const AuthSession({
    this.userId,
    this.email,
    this.name,
    this.photoUrl,
    this.isGuest = false,
  });

  const AuthSession.guest() : this(isGuest: true);

  bool get isAuthenticated => !isGuest && userId != null;

  /// Best short label for greetings: first name, else email local-part.
  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = email;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'Friend';
  }

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}
