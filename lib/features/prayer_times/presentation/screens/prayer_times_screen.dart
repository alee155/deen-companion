import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/prayer_times_provider.dart';
import '../widgets/next_prayer_hero_card.dart';
import '../widgets/prayer_time_row.dart';

class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerTimesAsync = ref.watch(prayerTimesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer times')),
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
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off_outlined, size: 40),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          error is Object
                              ? error.toString()
                              : 'Something went wrong.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(prayerTimesNotifierProvider.notifier)
                              .refresh(),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
