import 'package:deen_companion/features/prayer_logs/presentation/widgets/snap_photo_viewer.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_log_models.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_remote_datasource.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_repository_impl.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_logs/presentation/snap_viewing.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';
import 'presentation/_prayer_log_test_support.dart';

final _now = DateTime.now();

PrayerLog _log({
  bool hasSnap = false,
  bool viewed = false,
  bool expired = false,
  String? snapUrl,
  Duration endsIn = const Duration(hours: 1),
  bool windowKnown = true,
}) => PrayerLog(
  id: 'l1',
  prayer: PrayerName.asr,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: snapUrl,
  hasSnap: hasSnap,
  snapViewed: viewed,
  snapExpired: expired,
  windowKnown: windowKnown,
  windowStartsAt: _now.subtract(const Duration(hours: 1)),
  windowEndsAt: _now.add(endsIn),
  loggedAt: _now,
);

Map<String, dynamic> _json(Map<String, dynamic> extra) => {
  'id': 'l1',
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

DioException _gone(String code) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: 410,
    data: {
      'success': false,
      'error': {'code': code, 'message': 'gone'},
      'code': code,
      'message': 'gone',
    },
    requestOptions: RequestOptions(path: '/'),
  ),
);

void main() {
  group('the log carries the snap flags', () {
    test('parses hasSnap, snapViewed and snapExpired (false when absent)', () {
      final plain = prayerLogFromJson(_json({}));
      expect(plain.hasSnap, isFalse);
      expect(plain.snapViewed, isFalse);
      expect(plain.snapExpired, isFalse);
      final flagged = prayerLogFromJson(
        _json({'hasSnap': true, 'snapViewed': true, 'snapExpired': true}),
      );
      expect(flagged.hasSnap, isTrue);
      expect(flagged.snapViewed, isTrue);
      expect(flagged.snapExpired, isTrue);
    });
  });

  group('snapState', () {
    test('no flags and no link: no snap was sent to this group', () {
      expect(_log().snapState(_now), SnapState.none);
    });

    test('hasSnap: unopened', () {
      expect(_log(hasSnap: true).snapState(_now), SnapState.unopened);
    });

    test('snapViewed: opened', () {
      expect(_log(viewed: true).snapState(_now), SnapState.opened);
    });

    test('snapExpired wins over everything', () {
      expect(
        _log(hasSnap: true, viewed: true, expired: true).snapState(_now),
        SnapState.expired,
      );
    });

    test('the clock expires it the moment the window ends', () {
      final log = _log(hasSnap: true);
      expect(log.snapState(_now), SnapState.unopened);
      expect(
        log.snapState(_now.add(const Duration(hours: 1))),
        SnapState.expired,
        reason: 'now >= windowEndsAt',
      );
    });

    test('a live log has no window, so the clock does not expire it', () {
      final live = _log(
        hasSnap: true,
        windowKnown: false,
        endsIn: Duration.zero,
      );
      expect(live.snapState(_now), SnapState.unopened);
    });

    test('your own log with a link counts as a snap', () {
      expect(_log(snapUrl: 'https://x').snapState(_now), SnapState.unopened);
    });
  });

  group('POST /prayers/logs/{id}/view', () {
    late MockDio dio;
    late PrayerLogsRepositoryImpl repo;
    setUp(() {
      dio = MockDio();
      repo = PrayerLogsRepositoryImpl(PrayerLogsRemoteDataSourceImpl(dio));
    });

    test('posts with no body and returns the link', () async {
      when(() => dio.post(any())).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': {'snapUrl': 'https://img.test/once.jpg'},
        }),
      );
      final r = await repo.viewSnap('l1');
      expect((r as Success<OpenedSnap>).data.url, 'https://img.test/once.jpg');
      verify(() => dio.post(ApiEndpoints.prayerLogView('l1'))).called(1);
    });

    test('410 SNAP_ALREADY_VIEWED and SNAP_EXPIRED keep their codes', () async {
      when(() => dio.post(any())).thenThrow(_gone('SNAP_ALREADY_VIEWED'));
      var f = (await repo.viewSnap('l1') as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.snapAlreadyViewed);

      when(() => dio.post(any())).thenThrow(_gone('SNAP_EXPIRED'));
      f = (await repo.viewSnap('l1') as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.snapExpired);
    });
  });

  group('openMemberSnap', () {
    late ScriptedLogsRepo repo;
    late ProviderContainer container;
    Future<SnapViewerAction?>? opening;

    Future<void> pump(WidgetTester tester, PrayerLog log) async {
      repo = ScriptedLogsRepo();
      container = ProviderContainer(
        overrides: [prayerLogsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => opening = openMemberSnap(
                      context,
                      ref,
                      log: log,
                      title: 'Sara',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> tap(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('unopened: asks the server once, shows it, then marks opened', (
      tester,
    ) async {
      await pump(tester, _log(hasSnap: true));
      repo.viewResult = const Success(OpenedSnap(url: 'https://img.test/a'));
      await tap(tester);
      expect(repo.viewed, ['l1']);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(snapOutcomesProvider)['l1'], SnapState.opened);
      await opening;
    });

    testWidgets('the server\'s view time wins over the log\'s', (tester) async {
      await pump(tester, _log(hasSnap: true));
      repo.viewResult = const Success(
        OpenedSnap(url: 'https://img.test/a', viewDurationSeconds: 2),
      );
      await tap(tester);
      // The 2 s countdown ends the viewer by itself.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byTooltip('Close'), findsNothing);
      await opening;
    });

    testWidgets('410 already viewed: no viewer, tile becomes opened', (
      tester,
    ) async {
      await pump(tester, _log(hasSnap: true));
      repo.viewResult = const Error(
        PrayerLogFailure(
          'gone',
          code: PrayerLogErrorCode.snapAlreadyViewed,
          statusCode: 410,
        ),
      );
      await tap(tester);
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.textContaining('already opened'), findsOneWidget);
      expect(container.read(snapOutcomesProvider)['l1'], SnapState.opened);
      await opening;
    });

    testWidgets('410 expired: short message, tile becomes expired', (
      tester,
    ) async {
      await pump(tester, _log(hasSnap: true));
      repo.viewResult = const Error(
        PrayerLogFailure(
          'gone',
          code: PrayerLogErrorCode.snapExpired,
          statusCode: 410,
        ),
      );
      await tap(tester);
      expect(find.text('This snap has expired.'), findsOneWidget);
      expect(container.read(snapOutcomesProvider)['l1'], SnapState.expired);
      await opening;
    });

    testWidgets('a network failure says so and does not mark anything', (
      tester,
    ) async {
      await pump(tester, _log(hasSnap: true));
      repo.viewResult = const Error(NetworkFailure());
      await tap(tester);
      expect(find.textContaining('Couldn’t open this snap'), findsOneWidget);
      expect(container.read(snapOutcomesProvider), isEmpty);
      await opening;
    });

    testWidgets('already opened or expired: explains, never calls the API', (
      tester,
    ) async {
      await pump(tester, _log(viewed: true));
      await tap(tester);
      expect(find.textContaining('already opened'), findsOneWidget);
      expect(repo.viewed, isEmpty);
      await opening;

      await pump(tester, _log(hasSnap: true, expired: true));
      await tap(tester);
      expect(find.text('This snap has expired.'), findsOneWidget);
      expect(repo.viewed, isEmpty);
      await opening;
    });

    testWidgets('a snap past its window is not even requested', (tester) async {
      await pump(
        tester,
        _log(hasSnap: true, endsIn: const Duration(seconds: -1)),
      );
      await tap(tester);
      expect(repo.viewed, isEmpty);
      expect(find.text('This snap has expired.'), findsOneWidget);
      await opening;
    });
  });

  test('outcomes are laid over the feed, including live-only logs', () {
    final live = _log(hasSnap: true, windowKnown: false);
    final feed = [
      GroupMemberPrayers(
        userId: 'u',
        name: 'Sara',
        role: GroupRole.member,
        logs: [live],
      ),
    ];
    final out = applySnapOutcomes(feed, {'l1': SnapState.opened});
    expect(out.single.logs.single.snapState(_now), SnapState.opened);
    expect(applySnapOutcomes(feed, const {}), same(feed));
  });
}
