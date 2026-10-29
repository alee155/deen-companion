import '../domain/entities/bayan_video.dart';
import '../domain/entities/video_platform.dart';

/// "12:05", or "1:02:30" past an hour.
String formatVideoDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// "Watch on YouTube" / "Open link", for the button that leaves the app.
String openExternallyLabel(BayanVideo video) =>
    video.source.platform == VideoPlatform.other
    ? 'Open link'
    : 'Watch on ${video.source.platform.label}';
