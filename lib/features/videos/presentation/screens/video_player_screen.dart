import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/device/screen_awake.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../audio_player/presentation/providers/audio_player_provider.dart';
import '../../domain/entities/bayan_video.dart';
import '../providers/videos_providers.dart';
import '../video_actions.dart';
import '../video_labels.dart';
import '../widgets/video_player_surface.dart';
import '../widgets/video_tile.dart';

/// Plays one of the day's talks: the player on top (the platform's own, or a
/// poster that opens the link), then what it is, who is speaking, and more of
/// today's talks to carry on with.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;
  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with KeepScreenOnMixin<VideoPlayerScreen> {
  @override
  void initState() {
    super.initState();
    // A surah playing in the background would talk over the video.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final audio = ref.read(audioPlayerNotifierProvider);
      if (audio.isPlaying) {
        ref.read(audioPlayerNotifierProvider.notifier).togglePlayPause();
      }
    });
  }

  void _back() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final video = ref.watch(videoByIdProvider(widget.videoId));
    final daily = ref.watch(dailyVideosProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            Container(
              color: Colors.black,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 6.h),
                      child: Row(
                        children: [
                          GlassIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: _back,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              'Bayan of the day',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (video != null)
                      // Keyed, so moving to another talk starts a new player.
                      VideoPlayerSurface(key: ValueKey(video.id), video: video)
                    else
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Center(
                          child: daily.isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: video == null
                  ? _NotFound(loading: daily.isLoading, onBack: _back)
                  : _Details(video: video),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  final bool loading;
  final VoidCallback onBack;
  const _NotFound({required this.loading, required this.onBack});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: ShimmerBox(
          width: double.infinity,
          height: 120.h,
          borderRadius: 20.r,
        ),
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This talk isn’t in today’s set any more.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 12.h),
            FilledButton(
              onPressed: onBack,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emeraldInk,
                foregroundColor: AppColors.onEmeraldInk,
              ),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  final BayanVideo video;
  const _Details({required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = [
      for (final v
          in ref.watch(dailyVideosProvider).valueOrNull?.videos ??
              const <BayanVideo>[])
        if (v.id != video.id) v,
    ];
    final description = video.description;
    final duration = video.duration;

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 32.h),
      children: [
        Text(
          video.title,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: AppColors.inkText,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            if (video.category.isNotEmpty)
              _Chip(Icons.sell_rounded, video.category, strong: true),
            if (video.language.isNotEmpty)
              _Chip(Icons.translate_rounded, video.language),
            if (duration != null)
              _Chip(Icons.schedule_rounded, formatVideoDuration(duration)),
          ],
        ),
        SizedBox(height: 16.h),
        if (video.speaker.isNotEmpty)
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: AppColors.worshipAccentBg,
                child: Text(
                  video.speaker.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speaker',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      video.speaker,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (description != null) ...[
          SizedBox(height: 16.h),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.5.sp,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        SizedBox(height: 18.h),
        SizedBox(
          height: 46.h,
          child: OutlinedButton.icon(
            onPressed: () => openVideoExternally(context, video),
            icon: Icon(Icons.open_in_new_rounded, size: 18.sp),
            label: Text(openExternallyLabel(video)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emeraldInk,
              side: BorderSide(
                color: AppColors.emeraldInk.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
        ),
        if (others.isNotEmpty) ...[
          SizedBox(height: 26.h),
          Text(
            'More from today',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 12.h),
          for (final v in others) ...[
            VideoTile(
              video: v,
              onTap: () => context.pushReplacement('/video/${v.id}'),
            ),
            SizedBox(height: 10.h),
          ],
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool strong;
  const _Chip(this.icon, this.text, {this.strong = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
    decoration: BoxDecoration(
      color: strong ? AppColors.worshipAccentBg : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(14.r),
      border: Border.all(
        color: strong ? Colors.transparent : AppColors.borderWarm,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13.sp,
          color: strong ? AppColors.worshipAccent : AppColors.textMuted,
        ),
        SizedBox(width: 5.w),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: strong ? AppColors.worshipAccent : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
