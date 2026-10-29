import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/special_days/domain/special_days.dart';
import 'package:deen_companion/features/special_days/domain/special_days_failure.dart';
import 'package:deen_companion/features/special_days/domain/special_days_repository.dart';
import 'package:deen_companion/features/special_days/presentation/providers/special_days_providers.dart';
import 'package:deen_companion/features/special_days/presentation/screens/special_days_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

import '../prayer_logs/presentation/_prayer_log_test_support.dart';

Map<PrayerName, bool> _photos(int n) => {
  for (final (i, p) in PrayerName.values.indexed) p: i < n,
};

SpecialDays _idle({int photos = 5, DateTime? canStartAt}) => SpecialDays(
  eligible: true,
  images: _photos(photos),
  canStartAt: canStartAt,
  infoMessage: 'Please upload 5 different images.',
);

SpecialDays _running() => SpecialDays(
  eligible: true,
  active: true,
  startLocalDate: '2026-10-29',
  endsLocalDate: '2026-11-08',
  endsAt: DateTime.now().add(const Duration(days: 10)),
  daysRemaining: 10,
  images: _photos(5),
  canStartAt: DateTime.now().add(const Duration(days: 15)),
);

class FakeSpecialDaysRepo implements SpecialDaysRepository {
  SpecialDays state;
  Result<SpecialDays>? startResult;
  final calls = <String>[];
  FakeSpecialDaysRepo(this.state);

  @override
  Future<Result<SpecialDays>> getState() async => Success(state);

  Map<PrayerName, SpecialDayImage> images = {};
  int imageReads = 0;

  /// When set, the stored photos are not returned until it completes.
  Completer<void>? imagesGate;

  @override
  Future<Result<Map<PrayerName, SpecialDayImage>>> getImages() async {
    imageReads++;
    await imagesGate?.future;
    return Success(images);
  }

  @override
  Future<Result<SpecialDays>> setActive(bool active) async {
    calls.add('setActive($active)');
    if (active && startResult != null) return startResult!;
    state = active ? _running() : _idle();
    return Success(state);
  }

  @override
  Future<Result<SpecialDays>> uploadImage(
    PrayerName prayer,
    String path,
  ) async {
    calls.add('upload(${prayer.name})');
    return Success(state);
  }

  @override
  Future<Result<SpecialDays>> removeImage(PrayerName prayer) async {
    calls.add('remove(${prayer.name})');
    state = SpecialDays(
      eligible: true,
      images: {...state.images, prayer: false},
    );
    return Success(state);
  }
}

Future<FakeSpecialDaysRepo> _pump(
  WidgetTester tester,
  SpecialDays state, {
  Result<SpecialDays>? startResult,
  Map<PrayerName, String> previews = const {},
  Map<String, List<PrayerLog>> logsByDay = const {},
  Map<PrayerName, SpecialDayImage> stored = const {},
  Completer<void>? gate,
}) async {
  final repo = FakeSpecialDaysRepo(state)
    ..startResult = startResult
    ..images = {...stored}
    ..imagesGate = gate;
  tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(SignedIn.new),
        specialDaysRepositoryProvider.overrideWithValue(repo),
        specialDaysPreviewsProvider.overrideWith((ref) => previews),
        prayerLogsRangeProvider.overrideWith((ref, range) async => logsByDay),
        currentPrayerProvider.overrideWith(
          () => FixedCurrent(CurrentPrayerState(now: DateTime.now())),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SpecialDaysScreen()),
            ],
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return repo;
}

Finder get _switch => find.byType(Switch);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('idle: the five prayers with their photo status', (tester) async {
    await _pump(tester, _idle(photos: 2));
    expect(find.text('Your 5 photos'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    // Two photos (each with a tick) and three dashed "add" tiles.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.byTooltip('Replace Fajr photo'), findsOneWidget);
    expect(find.byTooltip('Replace Dhuhr photo'), findsOneWidget);
    expect(find.byTooltip('Replace Asr photo'), findsNothing);
    expect(find.text('Add photo'), findsNWidgets(3));
    expect(find.text('Off — add 3 more photos to begin'), findsOneWidget);
    expect(find.text('2 of 5 photos'), findsOneWidget, reason: 'hero chip');
    expect(find.text('Please upload 5 different images.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('starting without all photos shows the message, no API call', (
    tester,
  ) async {
    final repo = await _pump(tester, _idle(photos: 2));
    await tester.tap(_switch);
    await _settle(tester);
    expect(
      find.text('Please upload 5 different images.'),
      findsNWidgets(2),
      reason: 'the intro, and the toast',
    );
    expect(repo.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with all five photos the switch starts special days', (
    tester,
  ) async {
    final repo = await _pump(tester, _idle());
    expect(find.text('Off — your 5 photos are ready'), findsOneWidget);
    await tester.tap(_switch);
    await _settle(tester);
    expect(repo.calls, ['setActive(true)']);
    expect(find.text('Special days are on'), findsOneWidget);
    expect(
      find.text('10 days left'),
      findsNWidgets(2),
      reason: 'hero chip and calendar',
    );
    expect(find.text('Day 1 of 10'), findsOneWidget);
    expect(find.text('Until 7 Nov'), findsOneWidget, reason: 'hero chip');
    expect(
      find.text('Your 5 photos'),
      findsOneWidget,
      reason: 'editable while on',
    );
    expect(find.textContaining('Special days have started'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'the server still wants photos: its message, and the empty rows',
    (tester) async {
      await _pump(
        tester,
        _idle(),
        startResult: const Error(
          SpecialDaysFailure(
            'Please upload 5 different images (server).',
            code: SpecialDaysErrorCode.imagesRequired,
            statusCode: 409,
          ),
        ),
      );
      await tester.tap(_switch);
      await _settle(tester);
      expect(
        find.text('Please upload 5 different images (server).'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('prayer times missing: tells her where to set the location', (
    tester,
  ) async {
    await _pump(
      tester,
      _idle(),
      startResult: const Error(
        SpecialDaysFailure(
          'Prayer times not synced',
          code: SpecialDaysErrorCode.timesNotSynced,
          statusCode: 409,
        ),
      ),
    );
    await tester.tap(_switch);
    await _settle(tester);
    expect(find.textContaining('Open Prayer Times'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('too soon after the last period: switch is off with the date', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      _idle(canStartAt: DateTime.now().add(const Duration(days: 12))),
    );
    expect(find.textContaining('You can start again on'), findsOneWidget);
    await tester.tap(_switch);
    await _settle(tester);
    expect(repo.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('running: days left, and the switch asks before ending', (
    tester,
  ) async {
    final repo = await _pump(tester, _running());
    expect(find.text('Special days are on'), findsOneWidget);
    expect(
      find.text('10 days left'),
      findsNWidgets(2),
      reason: 'hero chip and calendar',
    );
    expect(find.text('Day 1 of 10'), findsOneWidget);

    await tester.tap(_switch);
    await _settle(tester);
    expect(find.text('End special days?'), findsOneWidget);
    expect(repo.calls, isEmpty, reason: 'nothing until she confirms');

    await tester.tap(find.text('Keep on'));
    await _settle(tester);
    expect(repo.calls, isEmpty);

    await tester.tap(_switch);
    await _settle(tester);
    await tester.tap(find.text('End'));
    await _settle(tester);
    expect(repo.calls, ['setActive(false)']);
    expect(find.text('My special days start today'), findsOneWidget);
    expect(find.textContaining('Special days ended'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('before a photo: the dua icon; after: the photo itself', (
    tester,
  ) async {
    // A real PNG on disk stands in for the photo that was sent.
    final tmp = Directory.systemTemp.createTempSync('sdp');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File('${tmp.path}/fajr.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        ),
      );
    await _pump(
      tester,
      _idle(photos: 2),
      previews: {PrayerName.fajr: file.path},
    );

    bool duaIcon(Widget w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/dua_icon.png';
    // Fajr shows its photo and Dhuhr is a photo too: only the three prayers
    // with no photo show the dua icon, never one behind a photo.
    expect(find.byWidgetPredicate(duaIcon), findsNWidgets(3));
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is FileImage),
      findsOneWidget,
    );

    // Tapping it opens the photo larger.
    await tester.tap(
      find.byWidgetPredicate((w) => w is Image && w.image is FileImage),
    );
    await _settle(tester);
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await _settle(tester);
    expect(find.byTooltip('Close'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a photo is shown for approval before it is used', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('sdp');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File('${tmp.path}/a.png')..writeAsBytesSync([1, 2, 3]);
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    PhotoChoice? result;
    var done = false;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPhotoPreview(
                  context,
                  prayer: PrayerName.asr,
                  path: file.path,
                );
                done = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await _settle(tester);
    expect(find.text('Asr photo'), findsOneWidget);
    expect(find.text('Use this photo'), findsOneWidget);
    expect(find.text('Choose another'), findsOneWidget);

    await tester.tap(find.text('Choose another'));
    await _settle(tester);
    expect(done, isTrue);
    expect(result, PhotoChoice.another);

    done = false;
    await tester.tap(find.text('go'));
    await _settle(tester);
    await tester.tap(find.text('Use this photo'));
    await _settle(tester);
    expect(result, PhotoChoice.use);

    done = false;
    result = null;
    await tester.tap(find.text('go'));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(done, isTrue);
    expect(result, isNull, reason: 'backing out sends nothing');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the hero does not move: it sits above the scrolling list', (
    tester,
  ) async {
    await _pump(tester, _idle(photos: 2));
    final before = tester.getTopLeft(find.text('Special days').first);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await _settle(tester);
    expect(tester.getTopLeft(find.text('Special days').first), before);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('running: a calendar of the days, with what was logged', (
    tester,
  ) async {
    // Day 3 of 10: two days gone, with 5/5 and 3/5 prayers logged.
    PrayerLog log(PrayerName p, String date) => PrayerLog(
      id: '$date-${p.name}',
      prayer: p,
      date: date,
      status: PrayerLogStatus.onTime,
      points: 5,
      snapUrl: null,
      windowStartsAt: DateTime(2026),
      windowEndsAt: DateTime(2026),
      loggedAt: DateTime(2026),
    );
    final state = SpecialDays(
      eligible: true,
      active: true,
      startLocalDate: '2026-10-29',
      endsLocalDate: '2026-11-08',
      daysRemaining: 8,
      images: _photos(5),
      canStartAt: DateTime.utc(2026, 11, 13, 10),
    );
    await _pump(
      tester,
      state,
      logsByDay: {
        '2026-10-29': [for (final p in PrayerName.values) log(p, '2026-10-29')],
        '2026-10-30': [
          log(PrayerName.fajr, '2026-10-30'),
          log(PrayerName.dhuhr, '2026-10-30'),
          log(PrayerName.asr, '2026-10-30'),
        ],
      },
    );
    expect(find.text('Day 3 of 10'), findsOneWidget);
    expect(find.text('8 days left'), findsNWidgets(2));
    // Ten day cells: 29, 30, 31 Oct then 1 to 7 Nov.
    for (final d in ['29', '30', '31', '1', '2', '3', '4', '5', '6', '7']) {
      expect(find.text(d), findsOneWidget, reason: 'day $d');
    }
    expect(
      find.text('8'),
      findsNothing,
      reason: 'the period ends before 8 Nov',
    );
    // The photo counter chip is one of the "5/5"s.
    expect(find.text('5/5'), findsNWidgets(2));
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('start again on 13 Nov'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('not running: no calendar', (tester) async {
    await _pump(tester, _idle(photos: 3));
    expect(find.textContaining('Day '), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'while special days are on her photos show, before the calendar',
    (tester) async {
      final repo = await _pump(tester, _running());
      expect(find.text('Your 5 photos'), findsOneWidget);
      expect(
        find.textContaining('change these while special days are on'),
        findsOneWidget,
      );
      // Every photo can be replaced or removed, and none is locked.
      for (final p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.byTooltip('Replace $p photo'), findsOneWidget, reason: p);
        expect(find.byTooltip('Remove $p photo'), findsOneWidget, reason: p);
      }
      // The photos come above the calendar.
      expect(
        tester.getTopLeft(find.text('Your 5 photos')).dy,
        lessThan(tester.getTopLeft(find.text('Day 1 of 10')).dy),
      );
      expect(
        repo.imageReads,
        greaterThan(0),
        reason: 'the stored photos were read',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('removing a photo while on asks first, and says what happens', (
    tester,
  ) async {
    final repo = await _pump(tester, _running());
    await tester.tap(find.byTooltip('Remove Asr photo'));
    await _settle(tester);
    expect(find.text('Remove the Asr photo?'), findsOneWidget);
    expect(find.textContaining('Asr won’t be logged for you'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.tap(find.text('Keep it'));
    await _settle(tester);
    expect(repo.calls, isEmpty);

    await tester.tap(find.byTooltip('Remove Asr photo'));
    await _settle(tester);
    await tester.tap(find.text('Remove'));
    await _settle(tester);
    expect(repo.calls, ['remove(asr)']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the stored photo shows on its card, with when it was added', (
    tester,
  ) async {
    // An image-less state to isolate the label: the server says Fajr has one.
    await tester.runAsync(() async {});
    await _pump(
      tester,
      _idle(photos: 1),
      stored: {
        PrayerName.fajr: SpecialDayImage(
          url: Uri.parse('https://res.cloudinary.com/x/f.jpg'),
          updatedAt: DateTime.utc(2026, 10, 29, 11),
        ),
      },
    );
    expect(find.text('Added 29 Oct'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Image && w.image is CachedNetworkImageProvider,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replacing or removing a photo reads the stored photos again', (
    tester,
  ) async {
    final repo = await _pump(tester, _idle(photos: 3));
    final before = repo.imageReads;
    await tester.tap(find.byTooltip('Remove Fajr photo'));
    await _settle(tester);
    expect(repo.imageReads, greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a photo that is on its way shimmers, with no icon behind it', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pump(
      tester,
      _idle(photos: 5),
      stored: {
        for (final p in PrayerName.values)
          p: SpecialDayImage(
            url: Uri.parse('https://res.cloudinary.com/x/${p.name}.jpg'),
            updatedAt: DateTime.utc(2026, 10, 29),
          ),
      },
      gate: gate,
    );
    // The stored photos are still being read: every tile shimmers.
    expect(find.byType(Shimmer), findsWidgets);
    bool duaIcon(Widget w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/dua_icon.png';
    expect(find.byWidgetPredicate(duaIcon), findsNothing);

    gate.complete();
    await _settle(tester);
    // Loaded (or not loadable in a test): still no icon behind a photo.
    expect(find.byWidgetPredicate(duaIcon), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a photo can be removed', (tester) async {
    final repo = await _pump(tester, _idle(photos: 3));
    await tester.tap(find.byTooltip('Remove Fajr photo'));
    await _settle(tester);
    expect(repo.calls, ['remove(fajr)']);
    expect(find.text('2/5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an account that is not eligible gets a plain message', (
    tester,
  ) async {
    await _pump(tester, SpecialDays.notEligible);
    expect(find.textContaining('aren’t available'), findsOneWidget);
    expect(_switch, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('eligibility drives the Profile entry', () async {
    final repo = FakeSpecialDaysRepo(_idle());
    final c = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(SignedIn.new),
        specialDaysRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(specialDaysEligibleProvider, (_, _) {});
    expect(sub.read(), isFalse, reason: 'until the server has answered');
    await c.read(specialDaysProvider.future);
    expect(sub.read(), isTrue);
    sub.close();
  });
}
