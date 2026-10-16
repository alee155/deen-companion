import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// What the group screen shows while the group loads: the same layout as the
/// real thing (header, snap summary, members list) drawn as grey shapes with a
/// shimmer sweeping across, so the page does not jump when the data arrives.
///
/// Each region shares one shimmer, so the highlight moves across it as a
/// single band. With reduced motion the shapes stay still.
class GroupDetailSkeleton extends StatelessWidget {
  /// How many member rows to draw.
  final int memberRows;

  const GroupDetailSkeleton({super.key, this.memberRows = 5});

  @override
  Widget build(BuildContext context) {
    final animate = !context.motion.reduced;
    return SingleChildScrollView(
      // Nothing to scroll yet; the real screen takes over once loaded.
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroSkeleton(animate: animate),
          _MembersSkeleton(animate: animate, rows: memberRows),
        ],
      ),
    );
  }
}

/// A solid shape for the shimmer to paint over. It must be opaque white: the
/// shimmer uses the shape's outline and fills it with its own colours.
class _Bone extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final bool _round;

  /// A rounded bar or box.
  const _Bone({this.width, required this.height, this.radius = 8})
    : _round = false;

  /// A rounded square of [size].
  const _Bone.block(double size, {this.radius = 8})
    : width = size,
      height = size,
      _round = false;

  /// A circle of [size].
  const _Bone.circle(double size)
    : width = size,
      height = size,
      radius = 0,
      _round = true;

  @override
  Widget build(BuildContext context) => Container(
    width: width?.w,
    height: height.h,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: _round ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: _round ? null : BorderRadius.circular(radius.r),
    ),
  );
}

/// Same dimensions as `GroupDetailHero`: the title row, the three chips and
/// the snap summary panel.
class _HeroSkeleton extends StatelessWidget {
  final bool animate;
  const _HeroSkeleton({required this.animate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        MediaQuery.of(context).padding.top + 58.h,
        20.w,
        16.h,
      ),
      child: Shimmer.fromColors(
        enabled: animate,
        baseColor: Colors.white.withValues(alpha: 0.10),
        highlightColor: Colors.white.withValues(alpha: 0.26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Bone.block(52, radius: 16),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bone(width: 190, height: 20.h, radius: 6),
                      SizedBox(height: 9.h),
                      _Bone(width: 240, height: 12.h, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                _Bone(width: 92, height: 26.h, radius: 14),
                SizedBox(width: 8.w),
                _Bone(width: 84, height: 26.h, radius: 14),
                SizedBox(width: 8.w),
                _Bone(width: 70, height: 26.h, radius: 14),
              ],
            ),
            SizedBox(height: 14.h),
            // The snap summary panel: ring, two lines, the streak.
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _Bone.circle(54),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bone(width: 120, height: 14.h, radius: 6),
                            SizedBox(height: 8.h),
                            _Bone(width: 150, height: 12.h, radius: 6),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          const _Bone.circle(24),
                          SizedBox(height: 5.h),
                          _Bone(width: 30, height: 16.h, radius: 5),
                          SizedBox(height: 4.h),
                          _Bone(width: 44, height: 9.h, radius: 4),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _Bone(width: 120, height: 11.h, radius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Members" heading and a card of member rows.
class _MembersSkeleton extends StatelessWidget {
  final bool animate;
  final int rows;
  const _MembersSkeleton({required this.animate, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            enabled: animate,
            baseColor: AppColors.borderWarm,
            highlightColor: AppColors.parchment,
            child: Row(
              children: [
                const _Bone.circle(18),
                SizedBox(width: 8.w),
                _Bone(width: 86, height: 18.h, radius: 6),
                SizedBox(width: 8.w),
                _Bone(width: 28, height: 20.h, radius: 12),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Shimmer.fromColors(
              enabled: animate,
              baseColor: AppColors.borderWarm,
              highlightColor: AppColors.parchment,
              child: Column(
                children: [
                  for (var i = 0; i < rows; i++) ...[
                    const _MemberRowSkeleton(),
                    if (i != rows - 1)
                      Padding(
                        padding: EdgeInsets.only(left: 60.w),
                        child: Container(height: 1, color: Colors.white),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One member card: rank, avatar, name, the stats line and the small box.
class _MemberRowSkeleton extends StatelessWidget {
  const _MemberRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        children: [
          SizedBox(
            width: 20.w,
            child: Align(
              alignment: Alignment.centerLeft,
              child: const _Bone.block(10, radius: 3),
            ),
          ),
          const _Bone.circle(44),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(width: 130, height: 14.h, radius: 6),
                SizedBox(height: 8.h),
                _Bone(width: 110, height: 11.h, radius: 5),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          const _Bone.block(30, radius: 9),
        ],
      ),
    );
  }
}
