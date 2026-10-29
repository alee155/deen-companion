import '../entities/video_platform.dart';
import 'video_platform_handler.dart';

/// YouTube: `watch?v=`, `youtu.be/`, `/embed/`, `/shorts/`, `/live/` and `/v/`
/// links, on any of its hosts. Played in the embedded iframe player.
class YouTubePlatformHandler extends VideoPlatformHandler {
  const YouTubePlatformHandler();

  static const _hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
    'youtu.be',
    'www.youtu.be',
  };

  /// YouTube ids are 11 characters of letters, digits, `-` and `_`.
  static final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// Path prefixes whose next segment is the id.
  static const _idPrefixes = {'embed', 'shorts', 'live', 'v'};

  @override
  VideoPlatform get platform => VideoPlatform.youtube;

  @override
  VideoPlayback get playback => VideoPlayback.embedded;

  @override
  bool matches(Uri uri) => _hosts.contains(uri.host.toLowerCase());

  @override
  String? videoIdFrom(Uri uri) {
    if (!matches(uri)) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    String? candidate;
    if (uri.host.toLowerCase().endsWith('youtu.be')) {
      candidate = segments.isEmpty ? null : segments.first;
    } else if (segments.isNotEmpty && segments.first == 'watch') {
      candidate = uri.queryParameters['v'];
    } else if (segments.length >= 2 && _idPrefixes.contains(segments.first)) {
      candidate = segments[1];
    }
    return candidate != null && _id.hasMatch(candidate) ? candidate : null;
  }

  @override
  Uri? thumbnailFor(String videoId) =>
      Uri.parse('https://img.youtube.com/vi/$videoId/hqdefault.jpg');
}
