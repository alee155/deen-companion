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

  /// The header's open height, and the slim bar it closes to (below the
  /// status bar) while the page scrolls.
  static double _expandedHeight(BuildContext context) => 372.h;
  static double _collapsedHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 62.h;

  @override
  Widget build(BuildContext context) {
    final expanded = _expandedHeight(context);
    final collapsed = _collapsedHeight(context);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        children: [
          // Only seen if the page is pulled down past the top: the header
          // keeps its dark colour instead of the page showing through.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: collapsed,
            child: ColoredBox(color: AppColors.heroSurface),
          ),
          RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top + 8.h,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // The whole page scrolls; only this stays, shrunk to a slim
                // bar with the next prayer and the bell.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: HomeHeaderDelegate(
                    expandedHeight: expanded,
                    collapsedHeight: collapsed,
                    builder: (context, height, collapse) => HomeSliderHeader(
                      height: height,
                      expandedHeight: expanded,
                      collapse: collapse,
                      onAvatarTap: () => context.go('/profile'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ReliabilityBanner(),
                        // Today's five prayers (signed-in users).
                        HomePrayerStrip(),
                      ],
                    ),
                  ),
                ),
                // The groups list: the old Groups tab, now here.
                HomeGroupsSection(topInset: collapsed),
                // Room under the last group for the floating bottom bar.
                SliverToBoxAdapter(child: SizedBox(height: 130.h)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
