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
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
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
              MediaQuery.of(context).padding.top + 28.h,
              24.w,
              28.h,
            ),
            child: Column(
              children: [
                _Avatar(
                  session: session,
                ).slideIn(RevealDirection.top, distance: 20),
                SizedBox(height: 14.h),
                Text(
                  signedIn ? session.displayName : 'Guest',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 60),
                ),
                SizedBox(height: 4.h),
                Text(
                  signedIn
                      ? (session.email ?? '')
                      : 'Everything is saved on this device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                  ),
                ).slideIn(
                  RevealDirection.bottomEnd,
                  delay: const Duration(milliseconds: 120),
                ),
                if (!signedIn) ...[
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child:
                            FilledButton(
                              onPressed: () => context.push('/login'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.heroSurface,
                                minimumSize: Size.fromHeight(48.h),
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
                                minimumSize: Size.fromHeight(48.h),
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
}

class _Avatar extends StatelessWidget {
  final AuthSession session;
  const _Avatar({required this.session});

  @override
  Widget build(BuildContext context) {
    final photo = session.photoUrl;
    final signedIn = session.isAuthenticated;
    return SizedBox(
      width: 108.w,
      height: 108.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(108.w),
            painter: StarPainter(
              fill: AppColors.gold.withValues(alpha: 0.16),
              stroke: AppColors.goldLight,
              strokeWidth: 1.4,
              inner: 0.8,
            ),
          ),
          Container(
            width: 78.w,
            height: 78.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.heroSurface,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: signedIn && photo != null
                ? Image.network(
                    photo,
                    width: 78.w,
                    height: 78.w,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _initials(),
                  )
                : signedIn
                ? _initials()
                : Icon(
                    Icons.person_rounded,
                    size: 40.sp,
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
      fontSize: 26.sp,
      fontWeight: FontWeight.w800,
      color: AppColors.goldLight,
    ),
  );
}
