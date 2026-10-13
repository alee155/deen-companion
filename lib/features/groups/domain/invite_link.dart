/// Parsing of invite URLs like
/// `https://deencompanion.dgexpense.com/invite/<token>`.
class InviteLink {
  InviteLink._();

  /// The app route that handles an invite (also the target of Android App
  /// Links, which hand the incoming URL's path straight to the router).
  static String routeFor(String token) =>
      '/invite/${Uri.encodeComponent(token)}';

  /// The token from an invite URL, or null if [url] isn't one.
  static String? tokenFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final s = uri.pathSegments;
    final i = s.indexOf('invite');
    if (i == -1 || i + 1 >= s.length || s[i + 1].isEmpty) return null;
    return s[i + 1];
  }
}
