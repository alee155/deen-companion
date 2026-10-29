import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_log_models.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_remote_datasource.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_repository_impl.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:deen_companion/features/snaps/presentation/widgets/add_groups_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';
import 'snap_fakes.dart';
import '../prayer_logs/presentation/_prayer_log_test_support.dart';

PrayerLog _log({
  List<String> groupIds = const ['g1'],
  bool expired = false,
  Duration endsIn = const Duration(hours: 1),
}) => PrayerLog(
  id: 'log-1',
  prayer: PrayerName.asr,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: 'https://x',
  snapExpired: expired,
  groupIds: groupIds,
  windowStartsAt: DateTime.now().subtract(const Duration(hours: 1)),
  windowEndsAt: DateTime.now().add(endsIn),
  loggedAt: DateTime.now(),
);

Map<String, dynamic> _json(Map<String, dynamic> extra) => {
  'id': 'log-1',
  'prayer': 'asr',
  'date': '2026-10-13',
  'status': 'on_time',
  'points': 5,
  'snapUrl': null,
  'windowStartsAt': '2026-10-13T10:05:00.000Z',
  'windowEndsAt': '2026-10-13T12:25:00.000Z',
  'loggedAt': '2026-10-13T10:30:00.000Z',
  ...extra,
};

DioException _http(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: {
      'success': false,
      'code': code,
      'message': 'no',
      'error': {'code': code, 'message': 'no'},
    },
    requestOptions: RequestOptions(path: '/'),
  ),
);

void main() {
  test('the log parses groupIds (empty when absent)', () {
    expect(prayerLogFromJson(_json({})).groupIds, isEmpty);
    expect(
      prayerLogFromJson(
        _json({
          'groupIds': ['g1', 'g2'],
        }),
      ).groupIds,
      ['g1', 'g2'],
    );
  });

  group('POST /prayers/logs/{id}/groups', () {
    late MockDio dio;
    late PrayerLogsRepositoryImpl repo;
    setUp(() {
      dio = MockDio();
      repo = PrayerLogsRepositoryImpl(PrayerLogsRemoteDataSourceImpl(dio));
    });

    test('sends the groups as JSON and returns the updated log', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': _json({
            'groupIds': ['g1', 'g2'],
          }),
        }),
      );
      final r = await repo.addSnapGroups('log-1', ['g2']);
      expect((r as Success<PrayerLog>).data.groupIds, ['g1', 'g2']);
      verify(
        () => dio.post(
          ApiEndpoints.prayerLogGroups('log-1'),
          data: {
            'groupIds': ['g2'],
          },
        ),
      ).called(1);
    });

    test('an empty selection is never sent', () async {
      final r = await repo.addSnapGroups('log-1', const []);
      expect(r, isA<Error>());
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });

    test('410 SNAP_EXPIRED, 403 and 429 keep their meaning', () async {
      Future<PrayerLogFailure> fail(int status, String code) async {
        when(
          () => dio.post(any(), data: any(named: 'data')),
        ).thenThrow(_http(status, code));
        return (await repo.addSnapGroups('log-1', ['g2']) as Error).failure
            as PrayerLogFailure;
      }

      expect(
        (await fail(410, 'SNAP_EXPIRED')).code,
        PrayerLogErrorCode.snapExpired,
      );
      expect(
        (await fail(403, 'FORBIDDEN')).code,
        PrayerLogErrorCode.notGroupMember,
      );
      expect(
        (await fail(429, 'THROTTLED')).code,
        PrayerLogErrorCode.rateLimited,
      );
    });
  });

  group('addableSnapLogProvider', () {
    ProviderContainer make({
      CurrentPrayerState? current,
      List<PrayerLog> logs = const [],
    }) {
      final c = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(SignedIn.new),
          currentPrayerProvider.overrideWith(
            () => FixedCurrent(current ?? _open()),
          ),
          prayerLogsProvider.overrideWith((ref, date) async => logs),
          myGroupsProvider.overrideWith(() => FakeMyGroups(sampleGroups)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<PrayerLog?> read(ProviderContainer c) async {
      await c.read(currentPrayerProvider.future);
      await c.read(prayerLogsProvider(null).future);
      await c.read(myGroupsProvider.future);
      return c.read(addableSnapLogProvider);
    }

    test('your logged snap with groups left to add is offered', () async {
      final log = _log();
      expect(await read(make(logs: [log])), log);
    });

    test('hidden once every group has it', () async {
      final log = _log(groupIds: ['g1', 'g2', 'g3']);
      expect(await read(make(logs: [log])), isNull);
    });

    test(
      'hidden when the prayer is not logged, or the window closed',
      () async {
        expect(
          await read(make(current: _open(logged: false), logs: [_log()])),
          isNull,
        );
        expect(
          await read(make(logs: [_log(endsIn: const Duration(seconds: -1))])),
          isNull,
        );
        expect(await read(make(logs: [_log(expired: true)])), isNull);
      },
    );
  });

  group('the sheet', () {
    Future<ScriptedLogsRepo> pump(
      WidgetTester tester, {
      PrayerLog? log,
      void Function(AddGroupsResult?)? onResult,
    }) async {
      final repo = ScriptedLogsRepo();
      repo.addResult = Success(_log(groupIds: ['g1', 'g2']));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(SignedIn.new),
            prayerLogsRepositoryProvider.overrideWithValue(repo),
            currentPrayerProvider.overrideWith(() => FixedCurrent(_open())),
            myGroupsProvider.overrideWith(() => FakeMyGroups(sampleGroups)),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final r = await showAddGroupsSheet(
                        context,
                        log: log ?? _log(),
                      );
                      onResult?.call(r);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return repo;
    }

    testWidgets('lists only the groups without the snap, no members', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Send to more groups'), findsOneWidget);
      expect(find.text('Namaz Family'), findsNothing, reason: 'g1 has it');
      expect(find.text('Quran Circle'), findsOneWidget);
      expect(find.text('Friday Friends'), findsOneWidget);
      expect(
        find.textContaining('until this prayer’s time ends'),
        findsOneWidget,
      );
      expect(find.text('Choose a group'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('adds the chosen groups and reports how many', (tester) async {
      AddGroupsResult? result;
      final repo = await pump(tester, onResult: (r) => result = r);
      await tester.tap(find.text('Quran Circle'));
      await tester.pump();
      expect(find.text('Add to 1 group'), findsOneWidget);
      await tester.tap(find.text('Friday Friends'));
      await tester.pump();
      expect(find.text('Add to 2 groups'), findsOneWidget);

      await tester.tap(find.text('Add to 2 groups'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.added.single.$1, 'log-1');
      expect(repo.added.single.$2, unorderedEquals(['g2', 'g3']));
      expect((result as AddedToGroups).count, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failure stays in the sheet and says why', (tester) async {
      final repo = await pump(tester);
      repo.addResult = const Error(NetworkFailure());
      await tester.tap(find.text('Quran Circle'));
      await tester.pump();
      await tester.tap(find.text('Add to 1 group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Add to 1 group'), findsOneWidget, reason: 'still open');
      expect(find.byType(AddGroupsSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the window closing resolves as expired', (tester) async {
      AddGroupsResult? result;
      final repo = await pump(tester, onResult: (r) => result = r);
      repo.addResult = const Error(
        PrayerLogFailure(
          'gone',
          code: PrayerLogErrorCode.snapExpired,
          statusCode: 410,
        ),
      );
      await tester.tap(find.text('Quran Circle'));
      await tester.pump();
      await tester.tap(find.text('Add to 1 group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, isA<SnapExpiredResult>());
      await tester.pumpWidget(const SizedBox());
    });
  });
}

CurrentPrayerState _open({bool logged = true}) => CurrentPrayerState(
  now: DateTime.now(),
  current: CurrentPrayer(
    prayer: PrayerName.asr,
    date: '2026-10-13',
    startsAt: DateTime.now().subtract(const Duration(hours: 1)),
    endsAt: DateTime.now().add(const Duration(hours: 1)),
    logged: logged,
    logId: logged ? 'log-1' : null,
  ),
);
