import 'package:equatable/equatable.dart';

import 'video_platform.dart';

/// Where a video lives and how it can be played: the platform, the platform's
/// own id for it (when it has one) and the link. Everything platform specific
/// that the rest of the app needs is here, so screens never inspect a URL.
class VideoSource extends Equatable {
  final VideoPlatform platform;

  /// The platform's id (a YouTube video id); null when it has none.
  final String? videoId;

  /// The link as given, opened when the video can't be played in the app.
  final Uri uri;
  final VideoPlayback playback;

  const VideoSource({
    required this.platform,
    required this.uri,
    required this.playback,
    this.videoId,
  });

  /// Playable inside the app: the platform allows it and we have the id.
  bool get canPlayInApp =>
      playback == VideoPlayback.embedded && videoId != null;

  @override
  List<Object?> get props => [platform, videoId, uri, playback];
}
