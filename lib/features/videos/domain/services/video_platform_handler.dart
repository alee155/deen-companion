import '../entities/video_platform.dart';

/// Everything the app knows about one video platform. A new platform is one
/// new handler (and an entry in the registry): nothing else looks at URLs.
abstract class VideoPlatformHandler {
  const VideoPlatformHandler();

  VideoPlatform get platform;

  /// Whether the app can play this platform's videos in an embedded player.
  VideoPlayback get playback;

  /// Whether [uri] is one of this platform's links.
  bool matches(Uri uri);

  /// The platform's id for the video that [uri] points at, or null if it has
  /// none or the link isn't a video link.
  String? videoIdFrom(Uri uri);

  /// A picture for [videoId], used when the API gave none.
  Uri? thumbnailFor(String videoId);
}
