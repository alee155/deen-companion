import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../statistics/presentation/providers/statistics_providers.dart';
import '../../../streaks/presentation/providers/streaks_providers.dart';
import '../../data/special_days_remote_datasource.dart';
import '../../data/special_days_repository_impl.dart';
import '../../domain/special_days.dart';
import '../../domain/special_days_failure.dart';
import '../../domain/special_days_repository.dart';

final specialDaysRemoteDataSourceProvider =
    Provider<SpecialDaysRemoteDataSource>(
      (ref) => SpecialDaysRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final specialDaysRepositoryProvider = Provider<SpecialDaysRepository>(
  (ref) =>
      SpecialDaysRepositoryImpl(ref.watch(specialDaysRemoteDataSourceProvider)),
);

/// The account's special-days state. A guest, a male or an unset account is
/// simply not eligible. Every action returns the failure it hit (null on
/// success) so the screen can word it, and keeps this state in step with the
/// server's answer.
class SpecialDaysNotifier extends AutoDisposeAsyncNotifier<SpecialDays> {
  SpecialDaysRepository get _repo => ref.read(specialDaysRepositoryProvider);

  @override
  Future<SpecialDays> build() async {
    final signedIn = ref.watch(
      authSessionProvider.select((s) => s.isAuthenticated),
    );
    if (!signedIn) return SpecialDays.notEligible;
    final result = await _repo.getState();
    return result.when(success: (d) => d, failure: (f) => throw f);
  }

  /// Starts ([active] true) or ends special days.
  Future<Failure?> setActive(bool active) async {
    final failure = await _apply(() => _repo.setActive(active));
    if (failure == null) _refreshWhatDepends();
    return failure;
  }

  /// Adds or replaces a photo; allowed while special days run too.
  Future<Failure?> uploadImage(PrayerName prayer, String path) async {
    final failure = await _apply(() => _repo.uploadImage(prayer, path));
    // The picture itself changed even if the yes/no flag did not: read the
    // fresh links.
    if (failure == null)
      ref.read(specialDayImagesRevisionProvider.notifier).state++;
    return failure;
  }

  Future<Failure?> removeImage(PrayerName prayer) async {
    final failure = await _apply(() => _repo.removeImage(prayer));
    if (failure == null)
      ref.read(specialDayImagesRevisionProvider.notifier).state++;
    return failure;
  }

  Future<Failure?> _apply(Future<Result<SpecialDays>> Function() call) async {
    final result = await call();
    switch (result) {
      case Success(:final data):
        state = AsyncData(data);
        return null;
      case Error(:final failure):
        // Our picture of the account may be stale (it can end by itself, or
        // change on another device): read it again for these.
        if (failure is SpecialDaysFailure &&
            const {
              SpecialDaysErrorCode.imagesRequired,
              SpecialDaysErrorCode.alreadyActive,
              SpecialDaysErrorCode.active,
              SpecialDaysErrorCode.tooSoon,
              SpecialDaysErrorCode.notAvailable,
            }.contains(failure.code)) {
          await _resync();
        }
        return failure;
    }
  }

  Future<void> _resync() async {
    final result = await _repo.getState();
    if (result case Success(:final data)) state = AsyncData(data);
  }

  /// The server logs prayers on her behalf while special days run (and stops
  /// when they end), so what shows logs, streaks and points is out of date.
  void _refreshWhatDepends() {
    ref.invalidate(prayerLogsProvider);
    ref.invalidate(prayerLogsRangeProvider);
    ref.invalidate(groupPrayersProvider);
    invalidateStreaks(ref);
    invalidateStatistics(ref);
    ref.read(currentPrayerProvider.notifier).refresh();
  }
}

final specialDaysProvider =
    AsyncNotifierProvider.autoDispose<SpecialDaysNotifier, SpecialDays>(
      SpecialDaysNotifier.new,
    );

/// Bumped when a photo is added, replaced or removed, so the links are read
/// again (the picture changed even where the yes/no flag did not). A counter
/// rather than an invalidate, because the notifier that bumps it is itself
/// something the images provider depends on.
final specialDayImagesRevisionProvider = StateProvider<int>((ref) => 0);

/// The stored photos with signed links, to show on the screen. Read each time
/// it opens (the links expire), and again after a photo is added, replaced or
/// removed. Empty for an account that isn't eligible, and a failed read is an
/// empty result too: the yes/no flags still say which prayers have a photo.
final specialDayImagesProvider =
    FutureProvider.autoDispose<Map<PrayerName, SpecialDayImage>>((ref) async {
      final eligible = ref.watch(
        specialDaysProvider.select((s) => s.valueOrNull?.eligible ?? false),
      );
      ref.watch(specialDayImagesRevisionProvider);
      if (!eligible) return const {};
      final result = await ref.read(specialDaysRepositoryProvider).getImages();
      return result.when(success: (d) => d, failure: (_) => const {});
    });

/// The photo files picked for each prayer this session, so a card can show the
/// photo that was sent. The server only says whether a prayer has a photo, not
/// what it looks like, so a photo added in an earlier session has no preview.
final specialDaysPreviewsProvider = StateProvider<Map<PrayerName, String>>(
  (ref) => const {},
);

/// Whether to offer special days at all: only when the server says so.
final specialDaysEligibleProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(specialDaysProvider).valueOrNull?.eligible ?? false,
);
