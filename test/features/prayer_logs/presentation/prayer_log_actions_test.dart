import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_support/prayer_area_support.dart';
import '_prayer_log_test_support.dart';

/// A repository that answers each log attempt from a script.
class _Scripted extends ScriptedLogsRepo {
  final List<Result<PrayerLog>> script;
  _Scripted(this.script);

  @override
  Future<Result<PrayerLog>> logPrayer(String imagePath) async {
    logged.add(imagePath);
    return script[logged.length <= script.length
        ? logged.length - 1
        : script.length - 1];
  }
}

/// The `force` flag of every refresh the actions asked for, in order.
final _refreshes = <bool>[];

class _Loader extends PrayerTimesLoader {
  final bool succeeds;
  _Loader(super.ref, {this.succeeds = true});

  @override
  Future<Result<PrayerTimesBundle>> refresh({bool force = false}) async {
    _refreshes.add(force);
    return succeeds
        ? Success(bundleOf([pt(14)]))
        : const Error(NetworkFailure());
  }
}

const _notSynced = Error<PrayerLog>(
  PrayerLogFailure(
    'Times not synced',
    code: PrayerLogErrorCode.timesNotSynced,
    statusCode: 409,
  ),
);

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  setUp(_refreshes.clear);

  ProviderContainer make(_Scripted repo, {bool loaderSucceeds = true}) {
    final c = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(SignedIn.new),
        prayerLogsRepositoryProvider.overrideWithValue(repo),
        prayerTimesLoaderProvider.overrideWith(
          (ref) => _Loader(ref, succeeds: loaderSucceeds),
        ),
        currentPrayerProvider.overrideWith(() => FixedCurrent(openState())),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'times not synced: sends the location once, then retries once',
    () async {
      final repo = _Scripted([_notSynced, Success(logOf(PrayerName.asr))]);
      final c = make(repo);
      final r = await c.read(prayerLogActionsProvider).log('/tmp/p.jpg');
      expect(r, isA<Success>());
      expect(_refreshes, [true], reason: 'one forced refresh');
      expect(repo.logged, ['/tmp/p.jpg', '/tmp/p.jpg']);
    },
  );

  test('if the location cannot be sent, the log is not retried', () async {
    final repo = _Scripted([_notSynced]);
    final c = make(repo, loaderSucceeds: false);
    final r = await c.read(prayerLogActionsProvider).log('/tmp/p.jpg');
    expect(
      ((r as Error).failure as PrayerLogFailure).code,
      PrayerLogErrorCode.timesNotSynced,
    );
    expect(repo.logged, hasLength(1));
  });

  test('a second "not synced" is returned, never a loop', () async {
    final repo = _Scripted([_notSynced, _notSynced, _notSynced]);
    final c = make(repo);
    final r = await c.read(prayerLogActionsProvider).log('/tmp/p.jpg');
    expect(r, isA<Error>());
    expect(repo.logged, hasLength(2), reason: 'one try, one retry');
    expect(_refreshes, hasLength(1));
  });

  test('other failures do not touch the times at all', () async {
    final repo = _Scripted([
      const Error(
        PrayerLogFailure(
          'No window',
          code: PrayerLogErrorCode.noActiveWindow,
          statusCode: 422,
        ),
      ),
    ]);
    final c = make(repo);
    final r = await c.read(prayerLogActionsProvider).log('/tmp/p.jpg');
    expect(r, isA<Error>());
    expect(repo.logged, hasLength(1));
    expect(
      _refreshes,
      isEmpty,
      reason: 'a closed window is not a times problem',
    );
  });

  test('a first-try success never refreshes the times', () async {
    final repo = _Scripted([Success(logOf(PrayerName.asr))]);
    final c = make(repo);
    await c.read(prayerLogActionsProvider).log('/tmp/p.jpg');
    expect(repo.logged, hasLength(1));
    expect(_refreshes, isEmpty);
  });
}
