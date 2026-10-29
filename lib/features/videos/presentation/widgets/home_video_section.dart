import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/videos_providers.dart';
import 'video_card.dart';

/// "Bayan of the day": the day's talks as a row under Categories. It
/// stays out of the way: nothing at all if there are none, and a quiet retry
/// line if they couldn't be loaded, so Home never shows a broken block.
class HomeVideoSection extends ConsumerWidget {
  /// How many Home shows; "See all" has the rest.
  static const homeLimit = 5;

  /// The section's title row, drawn by the screen so it matches the other
  /// sections on it. Shown only when there is something under it.
  final Widget Function() headerBuilder;

  const HomeVideoSection({super.key, required this.headerBuilder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyVideosProvider);
    // The picture is 16:9 of the card's width; the text under it grows with
    // the user's text size, so the row does too instead of overflowing.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final rowHeight = VideoCard.width * 9 / 16 + 86.h * scale;

    return async.when(
      data: (daily) {
        if (daily.videos.isEmpty) return const SizedBox.shrink();
        final shown = daily.videos.take(homeLimit).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerBuilder(),
            SizedBox(
              height: rowHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: shown.length,
                itemBuilder: (context, i) => VideoCard(
                  video: shown[i],
                  isLast: i == shown.length - 1,
                  onTap: () => context.push('/video/${shown[i].id}'),
                ).slideInAt(i, columns: 2, distance: 20),
              ),
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerBuilder(),
          SizedBox(
            height: rowHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.only(right: 12.w),
                    child: ShimmerBox(
                      width: VideoCard.width,
                      height: rowHeight,
                      borderRadius: 20.r,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      error: (_, _) => Pressable(
        onTap: () => ref.invalidate(dailyVideosProvider),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Text(
            'Videos unavailable · Retry',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
