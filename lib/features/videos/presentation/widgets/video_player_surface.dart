import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bayan_video.dart';
import '../../domain/entities/video_platform.dart';
import '../video_actions.dart';
import '../video_labels.dart';
import 'video_thumbnail.dart';
import 'youtube_player_view.dart';

/// Builds the in-app player for one platform's videos. [onUnavailable] is for
/// a player that finds it can't play this one (say, embedding is switched
/// off): the surface then offers to open the video outside the app instead.
typedef VideoPlayerBuilder =
    Widget Function(
      BuildContext context,
      BayanVideo video,
      VoidCallback onUnavailable,
    );

/// The players the app has, by platform. A platform with no entry (or a video
/// that can't be played in the app) gets the "open it" poster. To support a
/// new platform: write its handler, and add its player here.
final videoPlayerBuildersProvider =
    Provider<Map<VideoPlatform, VideoPlayerBuilder>>(
      (ref) => {
        VideoPlatform.youtube: (context, video, onUnavailable) =>
            YouTubePlayerView(video: video, onUnavailable: onUnavailable),
      },
    );

/// The 16:9 area at the top of the player screen: the right player for the
/// video's platform, or a poster that opens it elsewhere.
class VideoPlayerSurface extends ConsumerStatefulWidget {
  final BayanVideo video;
  const VideoPlayerSurface({super.key, required this.video});

  @override
  ConsumerState<VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends ConsumerState<VideoPlayerSurface> {
  bool _unavailable = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final builder = ref.watch(
      videoPlayerBuildersProvider,
    )[video.source.platform];
    if (!_unavailable && video.source.canPlayInApp && builder != null) {
      return builder(context, video, () => setState(() => _unavailable = true));
    }
    return VideoPoster(video: video, cantPlayHere: _unavailable);
  }
}

/// Picture, play button and "Watch on …": for what the app can't play itself.
class VideoPoster extends StatelessWidget {
  final BayanVideo video;

  /// The player tried and failed, so say why the poster is here.
  final bool cantPlayHere;
  const VideoPoster({
    super.key,
    required this.video,
    this.cantPlayHere = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: () => openVideoExternally(context, video),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoThumbnail(url: video.thumbnail),
            ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 34.sp,
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      cantPlayHere
                          ? 'This video can’t be played here. '
                                '${openExternallyLabel(video)}'
                          : openExternallyLabel(video),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
