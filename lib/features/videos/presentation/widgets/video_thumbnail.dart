import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// A video's picture, 16:9 by the caller. While it loads, and if it can't (or
/// there is none), a warm placeholder with a play mark stands in, so a card
/// never has a hole in it.
class VideoThumbnail extends StatelessWidget {
  final Uri? url;
  final BoxFit fit;
  const VideoThumbnail({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder();
    final u = url;
    if (u == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: u.toString(),
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.heroGradient,
      ),
    ),
    child: Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        size: 34.sp,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    ),
  );
}
