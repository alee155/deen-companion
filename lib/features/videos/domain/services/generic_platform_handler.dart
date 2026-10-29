import '../entities/video_platform.dart';
import 'video_platform_handler.dart';

/// Any other web link: no id, no picture of its own, and it can only be
/// opened outside the app. The registry falls back to it, so a link from a
/// platform we haven't met yet still shows up and still works.
class GenericPlatformHandler extends VideoPlatformHandler {
  const GenericPlatformHandler();

  @override
  VideoPlatform get platform => VideoPlatform.other;

  @override
  VideoPlayback get playback => VideoPlayback.external;

  @override
  bool matches(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  @override
  String? videoIdFrom(Uri uri) => null;

  @override
  Uri? thumbnailFor(String videoId) => null;
}
