import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/domain/explore_icon_assets.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../providers/auth_gate_provider.dart';
import '../widgets/welcome_emblem.dart';

class _Highlight {
  final String asset;
  final String title;
  final String body;
  const _Highlight(this.asset, this.title, this.body);
}

/// The app's front door. Continues the splash: the same ink-to-orange hero,
/// geometric lattice and logo badge, then a short showcase of what Deen
/// offers, with Login / Signup / guest in a card at the bottom.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static final _highlights = [
    _Highlight(
      exploreIconAssets['quran']!,
      'Read & listen to the Quran',
      'Surahs, Juz and Mushaf pages, with audio recitation.',
    ),
    _Highlight(
      exploreIconAssets['prayer_times']!,
      'Prayer times & real alarms',
      'Accurate times for where you are, with an adhan that rings on time.',
    ),
    _Highlight(
      exploreIconAssets['hadith']!,
      'A daily Ayat & Hadith',
      'One verse and one hadith, delivered to you every morning.',
    ),
    _Highlight(
      exploreIconAssets['names_of_allah']!,
      'Names of Allah & Duas',
      'Reflect on His names and call on Him with authentic duas.',
    ),
  ];

  final _pageController = PageController();
  Timer? _timer;
  int _index = 0;
  bool _continuingAsGuest = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.animateToPage(
        (_index + 1) % _highlights.length,
        duration: context.motion.duration(AppMotion.page * 2),
        curve: AppMotion.standard,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    if (_continuingAsGuest) return;
    HapticFeedback.selectionClick();
    setState(() => _continuingAsGuest = true);
    await ref.read(authGateProvider).markSeen();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.heroSurface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: GeometricPattern(
                  color: AppColors.goldLight.withValues(alpha: 0.07),
                  cell: 52,
                ),
              ),
              Column(
                children: [
                  Expanded(child: _hero()),
                  _bottomCard(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 12.w, top: 4.h),
              child: TextButton(
                onPressed: _continuingAsGuest ? null : _continueAsGuest,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // The content scales down on short screens instead of overflowing.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 375.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      style: TextStyle(
                        fontFamily: 'AmiriQuran',
                        fontSize: 22.sp,
                        color: AppColors.goldLight,
                      ),
                    ).slideIn(RevealDirection.top),
                    SizedBox(height: 4.h),
                    WelcomeEmblem(size: 250.w),
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 40.sp,
                        letterSpacing: 2,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ).slideIn(
                      RevealDirection.bottom,
                      delay: const Duration(milliseconds: 150),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Your daily companion in faith',
                      style: TextStyle(
                        fontSize: 13.sp,
                        letterSpacing: 0.4,
                        color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                      ),
                    ).appear(delay: const Duration(milliseconds: 250)),
                    SizedBox(height: 20.h),
                    SizedBox(
                      height: 92.h,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _highlights.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _HighlightCard(_highlights[i]),
                      ),
                    ).appear(delay: const Duration(milliseconds: 320)),
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _highlights.length; i++)
                          AnimatedContainer(
                            duration: context.motion.duration(AppMotion.normal),
                            curve: AppMotion.standard,
                            margin: EdgeInsets.symmetric(horizontal: 3.w),
                            height: 6.h,
                            width: _index == i ? 24.w : 6.w,
                            decoration: BoxDecoration(
                              color: _index == i
                                  ? AppColors.emeraldInk
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20.w,
        22.h,
        20.w,
        14.h + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressScale(
            child: SizedBox(
              height: 54.h,
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/login'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emeraldInk,
                  foregroundColor: AppColors.onEmeraldInk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
                child: Text(
                  'Log in',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ).slideIn(
            RevealDirection.start,
            delay: const Duration(milliseconds: 120),
          ),
          SizedBox(height: 10.h),
          PressScale(
            child: SizedBox(
              height: 54.h,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/signup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emeraldInk,
                  side: BorderSide(
                    color: AppColors.emeraldInk.withValues(alpha: 0.6),
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
                child: Text(
                  'Create an account',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ).slideIn(
            RevealDirection.end,
            delay: const Duration(milliseconds: 180),
          ),
          SizedBox(height: 4.h),
          TextButton(
            onPressed: _continuingAsGuest ? null : _continueAsGuest,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue as guest',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ).appear(delay: const Duration(milliseconds: 240)),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 11.5.sp,
                color: AppColors.textMuted,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                  text: 'Terms',
                  style: TextStyle(
                    color: AppColors.emeraldInk,
                    fontWeight: FontWeight.w700,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _open(AppConstants.termsAndConditionsUrl),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: AppColors.emeraldInk,
                    fontWeight: FontWeight.w700,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _open(AppConstants.privacyPolicyUrl),
                ),
              ],
            ),
          ).appear(delay: const Duration(milliseconds: 300)),
        ],
      ),
    );
  }
}

/// One feature highlight, on frosted glass over the hero.
class _HighlightCard extends StatelessWidget {
  final _Highlight highlight;
  const _HighlightCard(this.highlight);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Image.asset(highlight.asset, fit: BoxFit.contain),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlight.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    highlight.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.35,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.78),
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
