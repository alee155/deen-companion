import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/permissions/camera_permission_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../reliability_setup/domain/reliability_requirement.dart';
import '../../../reliability_setup/presentation/providers/reliability_providers.dart';
import '../../../reliability_setup/presentation/widgets/reliability_banner.dart';
import '../../../reliability_setup/presentation/widgets/reliability_setup_sheet.dart';
import '../../../daily_content/presentation/providers/daily_notification_service.dart';
import '../../../prayer_reminders/presentation/providers/prayer_alarm_launch_service.dart';
import '../widgets/home_groups_section.dart';
import '../widgets/home_prayer_strip.dart';
import '../widgets/home_slider_header.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../../push/presentation/providers/push_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Router is live and Home is on screen: deliver any notification tap
    // queued during launch and (once) ask for notification permission.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUp());
  }

  /// Home is the moment to ask for everything reminders and notifications
  /// need, so no alert ever fails later because of a missing permission.
  Future<void> _startUp() async {
    await ref.read(dailyNotificationServiceProvider).onHomeReady();
    await ref.read(prayerAlarmLaunchServiceProvider).onHomeReady();
    ref.read(pushServiceProvider).onHomeReady();

    // Android drops a permission request made while another dialog is up,
    // and Home's prayer times ask for location on their own — so wait for
    // that prompt to settle (this joins it rather than racing it).
    await ref.read(locationServiceProvider).requestPermission();
    if (!mounted) return;

    // Camera, for sending snaps — asked once here with the rest, so the
    // camera is ready the first time someone taps "Send snap".
    await requestCameraPermissionOnce(
      storage: ref.read(localStorageServiceProvider),
      service: ref.read(cameraPermissionServiceProvider),
    );
    if (!mounted) return;

    final reliability = ref.read(reliabilityServiceProvider);
    final status = await reliability.check();
    ref.invalidate(reliabilityStatusProvider);
    if (!mounted || status.allGranted || !reliability.shouldPrompt()) return;

    await reliability.markPrompted();
    if (mounted) await showReliabilitySetupSheet(context);
  }

  /// Pull to refresh: the groups list and today's prayers.
  Future<void> _refresh() async {
    ref.invalidate(myGroupsProvider);
    ref.invalidate(prayerLogsProvider);
    await ref.read(currentPrayerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340.h,
            child: HomeSliderHeader(
              height: 340.h,
              onAvatarTap: () => context.go('/profile'),
            ),
          ),
          Positioned(
            top: 300.h,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  // Room under the last group for the floating bottom bar.
                  padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 130.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 5.h,
                          width: 50.w,
                          decoration: BoxDecoration(
                            color: AppColors.borderWarm,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 22.h),
                      const ReliabilityBanner(),
                      // Today's five prayers (signed-in users).
                      const HomePrayerStrip(),
                      // The groups list: the old Groups tab, now here.
                      const HomeGroupsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
