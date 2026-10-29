import '../entities/video_platform.dart';
import '../entities/video_source.dart';
import 'generic_platform_handler.dart';
import 'video_platform_handler.dart';
import 'youtube_platform_handler.dart';

/// Works out, from a link, which platform a video is on and how it can be
/// played. Handlers are tried in order; [fallback] takes whatever none of them
/// claims.
class VideoPlatformRegistry {
  final List<VideoPlatformHandler> handlers;
  final VideoPlatformHandler fallback;

  const VideoPlatformRegistry({
    this.handlers = const [YouTubePlatformHandler()],
    this.fallback = const GenericPlatformHandler(),
  });

  VideoPlatformHandler handlerFor(Uri uri) {
    for (final h in handlers) {
      if (h.matches(uri)) return h;
    }
    return fallback;
  }

  /// The source for [uri]. [idHint] is the id the API gave, used when the link
  /// itself doesn't carry one the handler can read.
  VideoSource resolve(Uri uri, {String? idHint}) {
    final handler = handlerFor(uri);
    final id = handler.videoIdFrom(uri) ?? _usable(handler, idHint);
    return VideoSource(
      platform: handler.platform,
      videoId: id,
      uri: uri,
      playback: handler.playback,
    );
  }

  /// A picture for the video, from its platform.
  Uri? thumbnailFor(VideoSource source) {
    final id = source.videoId;
    if (id == null) return null;
    return handlerFor(source.uri).thumbnailFor(id);
  }

  /// A hint is only trusted for a platform that has ids at all.
  String? _usable(VideoPlatformHandler handler, String? hint) {
    if (hint == null || hint.isEmpty) return null;
    return handler.platform == VideoPlatform.other ? null : hint;
  }
}
