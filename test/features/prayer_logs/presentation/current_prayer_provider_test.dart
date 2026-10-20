import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_providers.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_logs_repository.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';
import '../../_support/prayer_area_support.dart';
import '../../auth/_support/auth_fakes.dart';

/// Stands in for the real loader: counts refreshes and answers with a fixed
/// result, never touching location, auth or the network.
class _FakeLoader extends PrayerTimesLoader {
  int calls = 0;
  final bool succeeds;
  _FakeLoader(super.ref, {this.succeeds = true});

  @override
  Future<Result<PrayerTimesBundle>> refresh({bool force = false}) async {
    calls++;
    return succeeds
        ? Success(bundleOf([pt(14)]))
        : const Error(NetworkFailure());
  }
}

class _FakeLogs implements PrayerLogsRepository {
  final List<Result<CurrentPrayerState>> currents;
  int calls = 0;
  _FakeLogs(this.currents);

  @override
  Future<Result<CurrentPrayerState>> getCurrent() async =>
      currents[calls++ < currents.length ? calls - 1 : currents.length - 1];

  @override
  Future<Result<List<GroupMemberPrayers>>> getGroupPrayers(
    String groupId, {
    String? date,
  }) async => const Success([]);

  @override
  Future<Result<PrayerLog>> logPrayer(
    String imagePath, {
    int? viewSeconds,
  }) async => const Error(NetworkFailure());

  @override
  Future<Result<void>> deleteLog(String id) async => const Success(null);

  @override
  Future<Result<List<PrayerLog>>> getLogs({String? date}) async =>
      const Success([]);

  @override
  Future<Result<List<PrayerLog>>> getLogsRange({
    required String from,
    required String to,
  }) async => const Success([]);
}

final _empty = CurrentPrayerState(now: DateTime.utc(2026, 10, 13));
final _open = CurrentPrayerState(
  now: DateTime.utc(2026, 10, 13),
  current: CurrentPrayer(
    prayer: PrayerName.asr,
    date: '2026-10-13',
    startsAt: DateTime.utc(2026, 10, 13, 10),
    endsAt: DateTime.utc(2026, 10, 13, 12),
    logged: false,
    logId: null,
  ),
);

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  ({ProviderContainer c, List<_FakeLoader> syncs}) make(
    _FakeLogs logs, {
    bool signedIn = true,
    bool syncSucceeds = true,
  }) {
    final storage = InMemoryStorageService();
    if (signedIn) {
      storage.put(
        AppConstants.settingsBoxName,
        AppConstants.authUserIdKey,
        'u1',
      );
    }
    final syncs = <_FakeLoader>[];
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStorageProvider.overrideWithValue(MemoryTokens(access: 'tok')),
        prayerLogsRepositoryProvider.overrideWithValue(logs),
        prayerTimesLoaderProvider.overrideWith((ref) {
          final s = _FakeLoader(ref, succeeds: syncSucceeds);
          syncs.add(s);
          return s;
        }),
      ],
    );
    addTearDown(c.dispose);
    return (c: c, syncs: syncs);
  }

  test('open window is returned as is, without syncing', () async {
    final logs = _FakeLogs([Success(_open)]);
    final t = make(logs);
    final s = await t.c.read(currentPrayerProvider.future);
    expect(s.current!.prayer, PrayerName.asr);
    expect(logs.calls, 1);
    expect(t.syncs, isEmpty);
  });

  test(
    'not synced: sends the location once, then asks the server again',
    () async {
      final logs = _FakeLogs([Success(_empty), Success(_open)]);
      final t = make(logs);
      final s = await t.c.read(currentPrayerProvider.future);
      expect(s.current, isNotNull);
      expect(t.syncs.single.calls, 1);
      expect(logs.calls, 2);
    },
  );

  test(
    'not synced and the location could not be sent: no second request',
    () async {
      final logs = _FakeLogs([Success(_empty)]);
      final t = make(logs, syncSucceeds: false);
      final s = await t.c.read(currentPrayerProvider.future);
      expect(s.isNotSynced, isTrue);
      expect(logs.calls, 1);
    },
  );

  test('failure surfaces as the provider error', () async {
    final t = make(_FakeLogs([const Error(NetworkFailure())]));
    await expectLater(
      t.c.read(currentPrayerProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('guests never hit the backend', () async {
    final logs = _FakeLogs([Success(_open)]);
    final t = make(logs, signedIn: false);
    final s = await t.c.read(currentPrayerProvider.future);
    expect(s.isNotSynced, isTrue);
    expect(await t.c.read(prayerLogsProvider(null).future), isEmpty);
    expect(logs.calls, 0);
  });

  test('undo refreshes the home state afterwards', () async {
    final logs = _FakeLogs([Success(_open)]);
    final t = make(logs);
    await t.c.read(currentPrayerProvider.future);
    expect(logs.calls, 1);
    final r = await t.c.read(prayerLogActionsProvider).undo('uuid-1');
    expect(r, isA<Success>());
    expect(logs.calls, 2);
  });

  test('a failed log still refreshes (the window may have closed)', () async {
    final logs = _FakeLogs([Success(_open)]);
    final t = make(logs);
    await t.c.read(currentPrayerProvider.future);
    final r = await t.c.read(prayerLogActionsProvider).log('/tmp/x.jpg');
    expect(r, isA<Error>());
    expect(logs.calls, 2);
  });
}
