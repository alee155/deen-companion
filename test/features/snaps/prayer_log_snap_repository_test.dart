import 'dart:io';

import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_remote_datasource.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_repository_impl.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/snaps/data/prayer_log_snap_repository.dart';
import 'package:deen_companion/features/snaps/domain/entities/snap_draft.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';
import '../prayer_logs/presentation/_prayer_log_test_support.dart';

const _draft = SnapDraft(
  groupId: 'g1',
  imagePath: '/tmp/prepared.jpg',
  viewSeconds: 10,
  caption: 'ignored by the API',
  recipientIds: ['u2', 'u3'],
);

PrayerLogFailure _noWindow() => PrayerLogFailure(
  'No prayer window is open right now',
  code: PrayerLogErrorCode.noActiveWindow,
  statusCode: 422,
  nextPrayer: PrayerName.dhuhr,
  nextStartsAt: DateTime.utc(2026, 10, 16, 6, 49),
);

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('PrayerLogSnapRepository', () {
    test('uploads the photo and reports the new log', () async {
      String? uploaded;
      final repo = PrayerLogSnapRepository(
        log: (path, {viewSeconds}) async {
          uploaded = path;
          return Success(logOf(PrayerName.dhuhr, id: 'log-77'));
        },
      );
      final r = await repo.sendSnap(_draft);
      expect(uploaded, '/tmp/prepared.jpg');
      expect((r as Success<SentSnap>).data.id, 'log-77');
    });

    test('sends the draft\'s view timer along with the photo', () async {
      int? sent;
      final repo = PrayerLogSnapRepository(
        log: (path, {viewSeconds}) async {
          sent = viewSeconds;
          return Success(logOf(PrayerName.fajr));
        },
      );
      await repo.sendSnap(_draft);
      expect(sent, _draft.viewSeconds);
    });

    test('sends only the photo: the API takes nothing else', () async {
      var calls = 0;
      final repo = PrayerLogSnapRepository(
        log: (path, {viewSeconds}) async {
          calls++;
          return Success(logOf(PrayerName.asr));
        },
      );
      await repo.sendSnap(_draft);
      expect(calls, 1);
    });

    test(
      'no open prayer becomes a plain sentence naming the next one',
      () async {
        final repo = PrayerLogSnapRepository(
          log: (_, {viewSeconds}) async => Error(_noWindow()),
        );
        final f = (await repo.sendSnap(_draft) as Error).failure;
        expect(f, isA<ServerFailure>());
        expect(f.message, startsWith('No prayer is open right now.'));
        expect(f.message, contains('Dhuhr starts at'));
      },
    );

    test('already logged is explained', () async {
      final repo = PrayerLogSnapRepository(
        log: (_, {viewSeconds}) async => const Error(
          PrayerLogFailure(
            'dup',
            code: PrayerLogErrorCode.alreadyLogged,
            statusCode: 409,
          ),
        ),
      );
      final f = (await repo.sendSnap(_draft) as Error).failure;
      expect(f.message, contains('already logged'));
    });

    test('a photo that is too large says so', () async {
      final repo = PrayerLogSnapRepository(
        log: (_, {viewSeconds}) async => const Error(
          PrayerLogFailure(
            'That photo is too large. The limit is 5 MB.',
            code: PrayerLogErrorCode.fileTooLarge,
            statusCode: 413,
          ),
        ),
      );
      final f = (await repo.sendSnap(_draft) as Error).failure;
      expect(f.message, contains('5 MB'));
    });

    test('being offline passes through unchanged', () async {
      final repo = PrayerLogSnapRepository(
        log: (_, {viewSeconds}) async => const Error(NetworkFailure()),
      );
      final f = (await repo.sendSnap(_draft) as Error).failure;
      expect(f, isA<NetworkFailure>());
    });
  });

  group('the real server\'s 422 (as returned by POST /prayers/logs)', () {
    late MockDio dio;
    late PrayerLogsRepositoryImpl logs;
    setUp(() {
      dio = MockDio();
      logs = PrayerLogsRepositoryImpl(PrayerLogsRemoteDataSourceImpl(dio));
    });

    test('is understood, with the next prayer and its start', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 422,
            requestOptions: RequestOptions(path: '/'),
            data: {
              'success': false,
              'statusCode': 422,
              'message': 'No prayer window is open right now',
              'code': 'NO_ACTIVE_PRAYER_WINDOW',
              'data': {
                'nextPrayer': 'dhuhr',
                'startsAt': '2026-10-16T06:49:00.000Z',
              },
              'path': '/api/prayers/logs',
              'timestamp': '2026-10-16T04:44:16.742Z',
            },
          ),
        ),
      );
      final tmp = await _tempPhoto();
      final failure =
          (await logs.logPrayer(tmp) as Error).failure as PrayerLogFailure;
      expect(failure.code, PrayerLogErrorCode.noActiveWindow);
      expect(failure.statusCode, 422);
      expect(failure.nextPrayer, PrayerName.dhuhr);
      expect(failure.nextStartsAt, DateTime.utc(2026, 10, 16, 6, 49));
    });
  });

  group('wiring', () {
    test('the app\'s send uses the real upload, not the placeholder', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(snapRepositoryProvider), isA<PrayerLogSnapRepository>());
    });

    test('sending a snap logs the prayer and refreshes the screens', () async {
      final scripted = ScriptedLogsRepo()
        ..logResult = Success(logOf(PrayerName.dhuhr, id: 'log-1'));
      final c = ProviderContainer(
        overrides: [
          prayerLogsRepositoryProvider.overrideWithValue(scripted),
          currentPrayerProvider.overrideWith(() => FixedCurrent(openState())),
        ],
      );
      addTearDown(c.dispose);

      final r = await c.read(snapRepositoryProvider).sendSnap(_draft);

      expect(scripted.logged, ['/tmp/prepared.jpg']);
      expect((r as Success<SentSnap>).data.id, 'log-1');
    });

    test(
      'a closed window reaches the send screen as a readable message',
      () async {
        final scripted = ScriptedLogsRepo()..logResult = Error(_noWindow());
        final c = ProviderContainer(
          overrides: [
            prayerLogsRepositoryProvider.overrideWithValue(scripted),
            currentPrayerProvider.overrideWith(() => FixedCurrent(openState())),
          ],
        );
        addTearDown(c.dispose);

        final r = await c.read(snapRepositoryProvider).sendSnap(_draft);
        expect(
          (r as Error<SentSnap>).failure.message,
          contains('No prayer is open right now'),
        );
      },
    );
  });
}

/// A real, small file, so the repository's size check has something to read.
Future<String> _tempPhoto() async {
  final dir = await Directory.systemTemp.createTemp('snap_test');
  addTearDown(() => dir.delete(recursive: true));
  final f = File('${dir.path}/p.jpg');
  await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
  return f.path;
}
