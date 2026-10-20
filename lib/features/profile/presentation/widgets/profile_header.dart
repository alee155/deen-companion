import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../auth/domain/entities/auth_session.dart';

/// Dark hero at the top of Profile. Adapts to guest / signed-in.
class ProfileHeader extends StatelessWidget {
  final AuthSession session;
  const ProfileHeader({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final signedIn = session.isAuthenticated;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 14.h,
              24.w,
              18.h,
            ),
            child: Column(
              children: [
                if (signedIn)
                  _signedInRow(context)
                else ...[
                  _Avatar(
                    session: session,
                  ).slideIn(RevealDirection.top, distance: 20),
                  SizedBox(height: 8.h),
                  Text(
                    'Guest',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ).slideIn(
                    RevealDirection.bottomStart,
                    delay: const Duration(milliseconds: 60),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Everything is saved on this device',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                    ),
                  ).slideIn(
                    RevealDirection.bottomEnd,
                    delay: const Duration(milliseconds: 120),
                  ),
                ],
                if (!signedIn) ...[
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child:
                            FilledButton(
                              onPressed: () => context.push('/login'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.heroSurface,
                                minimumSize: Size.fromHeight(44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              child: Text(
                                'Log in',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ).slideIn(
                              RevealDirection.bottomStart,
                              delay: const Duration(milliseconds: 180),
                            ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child:
                            OutlinedButton(
                              onPressed: () => context.push('/signup'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.goldLight,
                                side: BorderSide(
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                ),
                                minimumSize: Size.fromHeight(44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              child: Text(
                                'Create account',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ).slideIn(
                              RevealDirection.bottomEnd,
                              delay: const Duration(milliseconds: 220),
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Signed in: picture on the left, name and email beside it, and the edit
  /// button at the end of the same row.
  Widget _signedInRow(BuildContext context) {
    return Row(
      children: [
        _Avatar(
          session: session,
          size: 72,
        ).slideIn(RevealDirection.start, distance: 20),
        SizedBox(width: 14.w),
        Expanded(
          child:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    session.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ).slideIn(
                RevealDirection.bottomStart,
                delay: const Duration(milliseconds: 60),
              ),
        ),
        SizedBox(width: 8.w),
        OutlinedButton.icon(
          onPressed: () => context.push('/edit-profile'),
          icon: Icon(Icons.edit_rounded, size: 14.sp),
          label: Text(
            'Edit',
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.goldLight,
            visualDensity: VisualDensity.compact,
            minimumSize: Size(0, 34.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.7)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ).slideIn(
          RevealDirection.bottomEnd,
          delay: const Duration(milliseconds: 120),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final AuthSession session;

  /// Outer size of the star frame; the photo circle is inside it.
  final double size;
  const _Avatar({required this.session, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final photo = session.photoUrl;
    final signedIn = session.isAuthenticated;
    final frame = size.w;
    final circle = frame * 0.727;
    return SizedBox(
      width: frame,
      height: frame,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(frame),
            painter: StarPainter(
              fill: AppColors.gold.withValues(alpha: 0.16),
              stroke: AppColors.goldLight,
              strokeWidth: 1.4,
              inner: 0.8,
            ),
          ),
          Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.heroSurface,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: signedIn && photo != null
                ? CachedNetworkImage(
                    imageUrl: photo,
                    width: circle,
                    height: circle,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _initials(),
                    errorWidget: (_, _, _) => _initials(),
                  )
                : signedIn
                ? _initials()
                : Icon(
                    Icons.person_rounded,
                    size: circle * 0.52,
                    color: AppColors.goldLight,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _initials() => Text(
    session.initials,
    style: TextStyle(
      fontSize: (size * 0.25).sp,
      fontWeight: FontWeight.w800,
      color: AppColors.goldLight,
    ),
  );
}
