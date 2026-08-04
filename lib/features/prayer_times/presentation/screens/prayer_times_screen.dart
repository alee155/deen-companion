import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../providers/prayer_times_provider.dart';
import '../widgets/next_prayer_hero_card.dart';
import '../widgets/prayer_time_row.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerTimesAsync = ref.watch(prayerTimesNotifierProvider);

    return Scaffold(
      appBar: DeenAppBar(
        title: 'Prayer times',
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Monthly calendar',
            onPressed: () => context.push('/prayer-times/calendar'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(prayerTimesNotifierProvider.notifier).refresh(),
        child: prayerTimesAsync.when(
          data: (prayerTimes) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              NextPrayerHeroCard(prayerTimes: prayerTimes),
              const SizedBox(height: AppSpacing.xl),
              PrayerTimeRow(prayerTimes: prayerTimes),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              FailureView(
                failure: failureFrom(error),
                onRetry: () =>
                    ref.read(prayerTimesNotifierProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
