import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
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
    // Why a rebuild (and so a refetch) happens, in plain words.
    ref.listen(prayerSettingsRevisionProvider, (_, _) {
      FlowLog.log(
        _tag,
        'TRIGGER: the user changed method/school -> refetching',
      );
    });
    ref.listen(manualCityProvider, (_, city) {
      FlowLog.log(
        _tag,
        'TRIGGER: city ${city == null ? 'cleared' : 'picked: ${city.name}'} -> refetching',
      );
    });
    ref.listen(locationRecoveryProvider, (_, _) {
      FlowLog.log(
        _tag,
        'TRIGGER: location became available again -> refetching',
      );
    });
    ref.listen(authSessionProvider.select((s) => s.isAuthenticated), (_, now) {
      FlowLog.log(
        _tag,
        'TRIGGER: ${now ? 'signed in' : 'signed out'} -> refetching '
        '(${now ? 'account' : 'guest'} times)',
      );
    });
    // Watched, so each of these refetches by itself:
    // - the user picked a method or school (and the server must hear it);
    // - a city was picked or cleared;
    // - location recovered from an off/denied state;
    // - someone signed in or out (guest and account times differ).
    ref.watch(prayerSettingsRevisionProvider);
    ref.watch(manualCityProvider);
    ref.watch(locationRecoveryProvider);
    ref.watch(authSessionProvider.select((s) => s.isAuthenticated));
    FlowLog.log(
      _tag,
      'SCREEN WANTS TODAY\'S TIMES -> showing the cache first, then asking the server',
    );
    final cached = ref
        .read(prayerTimesRepositoryProvider)
        .getCachedToday(DateTime.now());
    FlowLog.log(
      _tag,
      cached == null
          ? 'NO CACHE: the screen shows a loading state'
          : 'CACHE SHOWN: fajr ${_hm(cached, cached.fajr)} · dhuhr ${_hm(cached, cached.dhuhr)} · '
                'asr ${_hm(cached, cached.asr)} · maghrib ${_hm(cached, cached.maghrib)} · '
                'isha ${_hm(cached, cached.isha)}',
    );
    return cached;
  }

  static const _tag = 'TODAY TIMES';

  /// `04:44` at the prayer location (what the user sees).
  static String _hm(PrayerTimes t, DateTime instant) {
    final c = t.wallClock(instant);
    return '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}';
  }

  @override
  Future<Result<PrayerTimes>> fetchFresh() async {
    final result = await ref.read(prayerTimesLoaderProvider).refresh();
    return result.when(
      success: (bundle) {
        final today = todayOf(bundle.days, DateTime.now());
        if (today == null) {
          FlowLog.error(_tag, 'THE SERVER SENT NO DAYS');
          return const Error<PrayerTimes>(ServerFailure());
        }
        FlowLog.log(
          _tag,
          'SCREEN UPDATED WITH SERVER TIMES: fajr ${_hm(today, today.fajr)} · '
          'dhuhr ${_hm(today, today.dhuhr)} · asr ${_hm(today, today.asr)} · '
          'maghrib ${_hm(today, today.maghrib)} · isha ${_hm(today, today.isha)} '
          '(offset ${today.utcOffset})',
        );
        return Success(today);
      },
      failure: (f) {
        FlowLog.error(
          _tag,
          'COULD NOT GET FRESH TIMES (the cache stays if there is one)',
          f.message,
        );
        return Error(f);
      },
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
    FlowLog.log(
      'CALENDAR',
      'OPENING ${arg.year}-${arg.month.toString().padLeft(2, '0')} as '
          '${signedIn ? 'signed-in account' : 'guest'}',
    );

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
      success: (bundle) {
        FlowLog.log('CALENDAR', 'MONTH LOADED: ${bundle.days.length} days');
        return [for (final d in bundle.days) d.times];
      },
      failure: (f) {
        FlowLog.error('CALENDAR', 'MONTH FAILED', f.message);
        throw f;
      },
    );
  }
}

final prayerCalendarNotifierProvider =
    AsyncNotifierProvider.family<
      PrayerCalendarNotifier,
      List<PrayerTimes>,
      YearMonth
    >(PrayerCalendarNotifier.new);
