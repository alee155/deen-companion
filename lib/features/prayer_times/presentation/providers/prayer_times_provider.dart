import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../domain/prayer_day_selector.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/prayer_times_bundle.dart';
import '../../domain/method_send_rule.dart';
import 'manual_city_provider.dart';
import 'prayer_calculation_settings_provider.dart';
import 'prayer_times_loader.dart';

export 'prayer_times_loader.dart'
    show
        prayerTimesRepositoryProvider,
        prayerTimesLoaderProvider,
        lockedDatesNoticeProvider;

/// Today's prayer times, cache-first: the last cached bundle shows at once,
/// then the server's answer replaces it if it differs.
class PrayerTimesNotifier extends CacheFirstStreamNotifier<PrayerTimes> {
  @override
  PrayerTimes? readCache() {
    // Watched, so each of these refetches by itself:
    // - the user picked a method or school (and the server must hear it);
    // - a city was picked or cleared;
    // - location recovered from an off/denied state;
    // - someone signed in or out (guest and account times differ).
    ref.watch(prayerSettingsRevisionProvider);
    ref.watch(manualCityProvider);
    ref.watch(locationRecoveryProvider);
    ref.watch(authSessionProvider.select((s) => s.isAuthenticated));
    return ref
        .read(prayerTimesRepositoryProvider)
        .getCachedToday(DateTime.now());
  }

  @override
  Future<Result<PrayerTimes>> fetchFresh() async {
    final result = await ref.read(prayerTimesLoaderProvider).refresh();
    return result.when(
      success: (bundle) {
        final today = todayOf(bundle.days, DateTime.now());
        return today == null
            ? const Error<PrayerTimes>(ServerFailure())
            : Success(today);
      },
      failure: (f) => Error(f),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final prayerTimesNotifierProvider =
    StreamNotifierProvider<PrayerTimesNotifier, PrayerTimes>(
      PrayerTimesNotifier.new,
    );

/// How the shown times were calculated ("Calculated: Karachi method, Hanafi
/// Asr"), from the same bundle the times came from. Null before a first fetch
/// or for unverified fallback times.
final prayerSourceLabelProvider = Provider<String?>((ref) {
  ref.watch(prayerTimesNotifierProvider);
  final bundle = ref.read(prayerTimesRepositoryProvider).getCachedBundle();
  return bundle?.method.name.isNotEmpty == true
      ? bundle!.method.sourceLabel
      : null;
});

// ── Monthly Prayer Calendar ──

typedef YearMonth = ({int year, int month});

class PrayerCalendarNotifier
    extends FamilyAsyncNotifier<List<PrayerTimes>, YearMonth> {
  @override
  Future<List<PrayerTimes>> build(YearMonth arg) async {
    ref.watch(prayerSettingsRevisionProvider);
    ref.watch(manualCityProvider);
    final signedIn = ref.watch(
      authSessionProvider.select((s) => s.isAuthenticated),
    );
    final repo = ref.read(prayerTimesRepositoryProvider);

    final Result<PrayerTimesBundle> result;
    if (signedIn) {
      result = await repo.fetchAccountMonth(year: arg.year, month: arg.month);
    } else {
      final place = await ref.read(prayerTimesLoaderProvider).resolvePlace();
      final choice = ref
          .read(prayerCalculationSettingsProvider.notifier)
          .choice;
      final send = MethodSendRule.resolve(
        chosenMethod: choice.methodId,
        chosenSchool: choice.schoolId,
        countryCode: place.countryCode,
      );
      result = await repo.fetchGuestMonth(
        place.coordinates,
        year: arg.year,
        month: arg.month,
        method: send.method,
        school: send.school,
      );
    }
    return result.when(
      success: (bundle) => [for (final d in bundle.days) d.times],
      failure: (f) => throw f,
    );
  }
}

final prayerCalendarNotifierProvider =
    AsyncNotifierProvider.family<
      PrayerCalendarNotifier,
      List<PrayerTimes>,
      YearMonth
    >(PrayerCalendarNotifier.new);
