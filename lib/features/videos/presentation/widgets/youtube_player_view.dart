import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../domain/entities/bayan_video.dart';

/// YouTube's own embedded player, started as soon as it opens. It handles
/// fullscreen and rotation itself. If YouTube refuses the video (the owner
/// turned embedding off, or it was removed) [onUnavailable] is called once, so
/// the screen can offer the link instead of a blank player.
class YouTubePlayerView extends StatefulWidget {
  final BayanVideo video;
  final VoidCallback onUnavailable;

  const YouTubePlayerView({
    super.key,
    required this.video,
    required this.onUnavailable,
  });

  @override
  State<YouTubePlayerView> createState() => _YouTubePlayerViewState();
}

class _YouTubePlayerViewState extends State<YouTubePlayerView> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.video.source.videoId!,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          // Related videos stay with this channel, not the whole of YouTube.
          strictRelatedVideos: true,
        ),
      );
  StreamSubscription<YoutubePlayerValue>? _errors;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _errors = _controller.listen((value) {
      if (value.error != YoutubeError.none && !_reported) {
        _reported = true;
        widget.onUnavailable();
      }
    });
  }

  @override
  void dispose() {
    _errors?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
}
