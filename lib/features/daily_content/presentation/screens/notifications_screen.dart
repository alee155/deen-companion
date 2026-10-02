import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/permissions/notification_permission_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/domain/explore_icon_assets.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/daily_content_providers.dart';
import '../providers/daily_notification_service.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../widgets/notification_card.dart';

/// Whether the OS currently allows notifications — the one thing that
/// silently stops this feature working.
final _notificationsAllowedProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationPermissionServiceProvider).isGranted(),
);

final _exactAlarmsAllowedProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(dailyNotificationSchedulerProvider).canScheduleExact(),
);

/// Notification centre, built like the other updated screens: dark hero,
/// pinned bar that solidifies on scroll, day-grouped list of bordered cards.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 140 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from system settings after fixing a permission.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(_notificationsAllowedProvider);
      ref.invalidate(_exactAlarmsAllowedProvider);
      // Exact alarms may have just been granted: re-arm with exact timing.
      ref.read(dailyNotificationServiceProvider).sync();
    }
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _failed = false);
    try {
      await ref.read(dailyNotificationServiceProvider).refreshHistory();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(DailyNotificationRecord record) {
    HapticFeedback.selectionClick();
    ref.read(notificationHistoryProvider.notifier).markRead(record.id);
    context.push('/daily-content?id=${Uri.encodeQueryComponent(record.id)}');
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(notificationHistoryProvider);
    final unread = records.where((r) => !r.read).length;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            RefreshIndicator(
              edgeOffset: 90.h,
              color: AppColors.emeraldInk,
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _hero(records.length, unread)),
                  ..._banners(),
                  ..._body(records),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 40.h,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(
                opacity: _bar,
                title: 'Notifications',
                trailingIcon: unread > 0 ? Icons.done_all_rounded : null,
                trailingTooltip: 'Mark all read',
                onTrailing: () {
                  HapticFeedback.selectionClick();
                  ref.read(notificationHistoryProvider.notifier).markAllRead();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(int total, int unread) => FeatureHero(
    title: 'Notifications',
    subtitle: unread == 0
        ? "You're all caught up."
        : 'You have $unread unread ${unread == 1 ? 'reading' : 'readings'}.',
    ghostIcon: Icons.notifications_rounded,
    chips: [
      FeatureHeroChip(Icons.mark_email_unread_rounded, '$unread unread'),
      FeatureHeroChip(Icons.history_rounded, '$total received'),
    ],
  );

  List<Widget> _banners() {
    final allowed = ref.watch(_notificationsAllowedProvider).value ?? true;
    final enabled = ref.watch(dailyNotificationEnabledProvider);
    final exactAllowed = ref.watch(_exactAlarmsAllowedProvider).value ?? true;

    final banner = !allowed
        ? _Banner(
            icon: Icons.notifications_off_rounded,
            message:
                'Notifications are blocked for Deen, so the daily Ayat & '
                'Hadith can’t reach you.',
            action: 'Open settings',
            onAction: () => ref
                .read(notificationPermissionServiceProvider)
                .openAppSettings(),
          )
        : !enabled
        ? _Banner(
            icon: Icons.toggle_off_rounded,
            message: 'The daily Ayat & Hadith notification is switched off.',
            action: 'Turn on',
            onAction: () =>
                ref.read(dailyNotificationEnabledProvider.notifier).set(true),
          )
        : !exactAllowed
        ? _Banner(
            icon: Icons.alarm_off_rounded,
            message:
                'Allow “Alarms & reminders” so it arrives on time instead of '
                'being delayed.',
            action: 'Allow',
            onAction: () => ref
                .read(dailyNotificationSchedulerProvider)
                .requestExactAlarmPermission(),
          )
        : null;

    if (banner == null) return const [];
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
        sliver: SliverToBoxAdapter(child: banner),
      ),
    ];
  }

  List<Widget> _body(List<DailyNotificationRecord> records) {
    if (_loading && records.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, _) => SizedBox(height: 12.h),
            itemBuilder: (_, _) => ShimmerBox(
              width: double.infinity,
              height: 96.h,
              borderRadius: 22.r,
            ),
          ),
        ),
      ];
    }

    if (_failed && records.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _Message(
            icon: Icons.error_outline_rounded,
            title: "Couldn't load notifications",
            body: 'Check your connection and try again.',
            action: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emeraldInk,
              ),
              onPressed: _refresh,
              child: Text(
                'Try again',
                style: TextStyle(color: AppColors.onEmeraldInk),
              ),
            ),
          ),
        ),
      ];
    }

    if (records.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: _Message(
            useExploreIcons: true,
            title: 'No notifications yet',
            body:
                'Your daily Ayat & Hadith will appear here once it is '
                'delivered, about 20 minutes after Fajr.',
          ),
        ),
      ];
    }

    // One section per day, newest first — same section header as
    // "Your groups": bold title with a count pill.
    final sections = <String, List<DailyNotificationRecord>>{};
    for (final r in records) {
      sections.putIfAbsent(_dayLabel(r.receivedAt), () => []).add(r);
    }

    final slivers = <Widget>[];
    var index = 0;
    for (final entry in sections.entries) {
      final start = index;
      index += entry.value.length;
      slivers.add(_sectionHeader(entry.key, entry.value.length));
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => SizedBox(height: 12.h),
            itemBuilder: (context, i) {
              final record = entry.value[i];
              return NotificationCard(
                record: record,
                onTap: () => _open(record),
              ).slideInAt(start + i);
            },
          ),
        ),
      );
    }
    return slivers;
  }

  /// Same header as "Your groups": bold title with a count pill.
  Widget _sectionHeader(String label, int count) => SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 12.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.worshipAccent,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  static String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(
      when.year == now.year ? 'd MMMM' : 'd MMMM y',
    ).format(when);
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onAction;

  const _Banner({
    required this.icon,
    required this.message,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(12.w, 12.h, 8.w, 12.h),
    decoration: BoxDecoration(
      color: AppColors.worshipAccentBg,
      borderRadius: BorderRadius.circular(22.r),
      border: Border.all(color: AppColors.emeraldInk.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Icon(icon, size: 21.sp, color: AppColors.worshipAccent),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.4,
              color: AppColors.inkText,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(
            action,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.worshipAccent,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final IconData? icon;
  final bool useExploreIcons;
  final String title;
  final String body;
  final Widget? action;

  const _Message({
    this.icon,
    this.useExploreIcons = false,
    required this.title,
    required this.body,
    this.action,
  });

  Widget _tile(String asset) => Container(
    width: 62.w,
    height: 62.w,
    padding: EdgeInsets.all(13.w),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(18.r),
      border: Border.all(color: AppColors.borderWarm, width: 1.2.w),
    ),
    child: Image.asset(asset, fit: BoxFit.contain),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(36.w, 56.h, 36.w, 0),
    child: Column(
      children: [
        if (useExploreIcons)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tile(exploreIconAssets['quran']!),
              SizedBox(width: 12.w),
              _tile(exploreIconAssets['hadith']!),
            ],
          ).popIn()
        else
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32.sp, color: AppColors.worshipAccent),
          ),
        SizedBox(height: 18.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        if (action != null) ...[SizedBox(height: 16.h), action!],
      ],
    ),
  );
}
