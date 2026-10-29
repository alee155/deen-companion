import 'package:deen_companion/features/videos/domain/entities/video_platform.dart';
import 'package:deen_companion/features/videos/domain/services/video_platform_handler.dart';
import 'package:deen_companion/features/videos/domain/services/video_platform_registry.dart';
import 'package:deen_companion/features/videos/domain/services/youtube_platform_handler.dart';
import 'package:flutter_test/flutter_test.dart';

const registry = VideoPlatformRegistry();
const _id = '5ES0cFPNpbE';

void main() {
  const yt = YouTubePlatformHandler();

  group('YouTube links', () {
    test('every common form gives the same id', () {
      for (final url in [
        'https://www.youtube.com/watch?v=$_id',
        'https://youtube.com/watch?v=$_id&t=30s',
        'https://m.youtube.com/watch?v=$_id',
        'https://youtu.be/$_id',
        'https://youtu.be/$_id?si=abc',
        'https://www.youtube.com/embed/$_id',
        'https://www.youtube-nocookie.com/embed/$_id',
        'https://www.youtube.com/shorts/$_id',
        'https://www.youtube.com/live/$_id',
        'https://www.youtube.com/v/$_id',
        'https://music.youtube.com/watch?v=$_id',
        'HTTPS://WWW.YOUTUBE.COM/watch?v=$_id',
      ]) {
        expect(yt.videoIdFrom(Uri.parse(url)), _id, reason: url);
      }
    });

    test('a YouTube link that is not a video has no id', () {
      for (final url in [
        'https://www.youtube.com/',
        'https://www.youtube.com/@channel',
        'https://www.youtube.com/watch',
        'https://www.youtube.com/watch?v=short',
        'https://www.youtube.com/playlist?list=PL123',
        'https://youtu.be/',
      ]) {
        expect(yt.videoIdFrom(Uri.parse(url)), isNull, reason: url);
      }
    });

    test('only its own hosts match', () {
      expect(
        yt.matches(Uri.parse('https://www.youtube.com/watch?v=$_id')),
        isTrue,
      );
      expect(
        yt.matches(Uri.parse('https://evil-youtube.com/watch?v=$_id')),
        isFalse,
      );
      expect(
        yt.matches(Uri.parse('https://youtube.com.evil.io/watch?v=$_id')),
        isFalse,
      );
      expect(
        yt.videoIdFrom(Uri.parse('https://vimeo.com/watch?v=$_id')),
        isNull,
      );
    });

    test('plays in the app and has a picture for the id', () {
      expect(yt.playback, VideoPlayback.embedded);
      expect(
        yt.thumbnailFor(_id).toString(),
        'https://img.youtube.com/vi/$_id/hqdefault.jpg',
      );
    });
  });

  group('the registry', () {
    test('a YouTube link is a YouTube source that plays in the app', () {
      final s = registry.resolve(
        Uri.parse('https://www.youtube.com/watch?v=$_id'),
      );
      expect(s.platform, VideoPlatform.youtube);
      expect(s.videoId, _id);
      expect(s.playback, VideoPlayback.embedded);
      expect(s.canPlayInApp, isTrue);
    });

    test('the API\'s own id is used when the link has none we can read', () {
      final s = registry.resolve(
        Uri.parse('https://www.youtube.com/some/odd/path'),
        idHint: _id,
      );
      expect(s.videoId, _id);
      expect(s.canPlayInApp, isTrue);
    });

    test('a link from another site is kept, and opens outside the app', () {
      final s = registry.resolve(
        Uri.parse('https://vimeo.com/123456'),
        idHint: 'ignored',
      );
      expect(s.platform, VideoPlatform.other);
      expect(s.videoId, isNull, reason: 'a hint means nothing off YouTube');
      expect(s.playback, VideoPlayback.external);
      expect(s.canPlayInApp, isFalse);
      expect(s.uri.toString(), 'https://vimeo.com/123456');
    });

    test('pictures come from the platform that owns the video', () {
      final s = registry.resolve(Uri.parse('https://youtu.be/$_id'));
      expect(
        registry.thumbnailFor(s).toString(),
        'https://img.youtube.com/vi/$_id/hqdefault.jpg',
      );
      expect(
        registry.thumbnailFor(
          registry.resolve(Uri.parse('https://vimeo.com/1')),
        ),
        isNull,
      );
    });

    test('a new platform is one handler: it is tried before the fallback', () {
      final r = VideoPlatformRegistry(
        handlers: const [YouTubePlatformHandler(), _VimeoHandler()],
      );
      final s = r.resolve(Uri.parse('https://vimeo.com/76979871'));
      expect(s.videoId, '76979871');
      expect(s.platform, VideoPlatform.other);
      expect(s.playback, VideoPlayback.external);
      expect(
        r.thumbnailFor(s).toString(),
        'https://vumbnail.example/76979871.jpg',
      );
      // And YouTube still goes to YouTube.
      expect(
        r.resolve(Uri.parse('https://youtu.be/$_id')).platform,
        VideoPlatform.youtube,
      );
    });
  });
}

/// A made-up second platform, to show nothing else has to change for it.
class _VimeoHandler extends VideoPlatformHandler {
  const _VimeoHandler();
  @override
  VideoPlatform get platform => VideoPlatform.other;
  @override
  VideoPlayback get playback => VideoPlayback.external;
  @override
  bool matches(Uri uri) => uri.host.endsWith('vimeo.com');
  @override
  String? videoIdFrom(Uri uri) =>
      uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  @override
  Uri? thumbnailFor(String videoId) =>
      Uri.parse('https://vumbnail.example/$videoId.jpg');
}
