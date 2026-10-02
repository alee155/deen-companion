import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../ads/presentation/providers/app_open_ad_manager.dart';
import '../splash_branding.dart';
import '../widgets/star_ornament.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SplashBranding.timeline,
  );

  // Stages on the single timeline (fractions of SplashBranding.timeline).
  late final Animation<double> _star = _stage(0.00, 0.55, Curves.easeOut);
  late final Animation<double> _logo = _stage(0.08, 0.50, AppMotion.pop);
  late final Animation<double> _logoFade = _stage(0.08, 0.32, Curves.easeOut);
  late final Animation<double> _title = _stage(0.40, 0.68, AppMotion.entrance);
  late final Animation<double> _rule = _stage(0.52, 0.78, AppMotion.emphasized);
  late final Animation<double> _verse = _stage(0.62, 0.88, AppMotion.entrance);

  Animation<double> _stage(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve),
      );

  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Start the clock only once the first splash frame is actually on
    // screen, so engine warm-up jank can't eat into the visible time.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the logo before the first paint to avoid a pop-in.
    precacheImage(const AssetImage(SplashBranding.logoAsset), context);
  }

  Future<void> _run() async {
    if (!mounted || _started) return;
    _started = true;
    if (context.motion.reduced) {
      _controller.value = 1;
      await Future<void>.delayed(SplashBranding.reducedMotionHold);
    } else {
      await _controller.forward().orCancel.catchError((_) {});
    }
    _goNext();
  }

  void _goNext() {
    if (!mounted) return;
    final storage = ref.read(localStorageServiceProvider);
    final authGateSeen =
        storage.get<bool>(
          AppConstants.settingsBoxName,
          AppConstants.authGateSeenKey,
        ) ??
        false;

    // The one-time App Open ad is offered at the very start of the session,
    // over whichever screen the user lands on: Welcome on a first install,
    // Home for a returning user. Fire-and-forget — it shows once it has
    // loaded and never blocks navigation.
    ref.read(appOpenAdManagerProvider).maybeShowOnColdStart();

    context.go(authGateSeen ? '/' : '/welcome');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = 132.w;
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundGradientStart,
              AppColors.backgroundGradientEnd,
            ],
          ),
        ),
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 260.w,
                  height: 260.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0.55 * _star.value,
                        child: StarOrnament(
                          progress: _star.value,
                          color: AppColors.emeraldInk,
                          size: 250.w,
                        ),
                      ),
                      Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: 0.7 + 0.3 * _logo.value,
                          child: Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(34.r),
                              border: Border.all(
                                color: AppColors.emeraldInk.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emeraldInk.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34.r),
                              child: Image.asset(
                                SplashBranding.logoAsset,
                                width: logoSize,
                                height: logoSize,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28.h),
                Opacity(
                  opacity: _title.value,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - _title.value)),
                    child: Text(
                      AppConstants.appName,
                      style: AppTypography.heroSerif.copyWith(
                        color: AppColors.inkText,
                        fontSize: 38.sp,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  width: 56.w * _rule.value,
                  height: 1.5,
                  color: AppColors.emeraldInk,
                ),
                SizedBox(height: 14.h),
                Opacity(
                  opacity: _verse.value,
                  child: Column(
                    children: [
                      Text(
                        SplashBranding.bismillah,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 20.sp,
                          color: AppColors.emeraldInk,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        SplashBranding.tagline,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
