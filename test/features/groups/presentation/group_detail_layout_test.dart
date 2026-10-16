import 'package:deen_companion/features/prayer_logs/presentation/widgets/snap_photo_viewer.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/groups/presentation/widgets/snap_widgets.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/widgets/prayer_dots_row.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'admin1', email: 'a@b.c', name: 'Alee');
}

const _detail = GroupDetail(
  id: 'g1',
  name: 'Namaz Family Group',
  description: 'Daily recitation group',
  inviteCode: 'JbwjmgCS',
  members: [
    GroupMember(
      userId: 'admin1',
      name: 'Alee Khan',
      email: 'alee@b.c',
      role: GroupRole.admin,
    ),
    GroupMember(
      userId: 'member1',
      name: 'Sara Ahmed',
      email: 's@b.c',
      role: GroupRole.member,
    ),
  ],
);

PrayerLog _log(
  PrayerName prayer, {
  required String id,
  required DateTime at,
  String? url,
}) => PrayerLog(
  id: id,
  prayer: prayer,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: url,
  windowStartsAt: at.subtract(const Duration(hours: 1)),
  windowEndsAt: at.add(const Duration(hours: 1)),
  loggedAt: at,
);

final _noon = DateTime(2026, 10, 13, 12);

/// Alee (the viewer) prayed Fajr and Dhuhr; Sara prayed Asr, then Maghrib
/// (her latest). Everyone's logs carry a signed photo link unless [photos] is
/// false.
List<GroupMemberPrayers> _feed({bool photos = true}) {
  String? link(String name) =>
      photos ? 'https://img.test/$name.jpg?sig=1' : null;
  return [
    GroupMemberPrayers(
      userId: 'admin1',
      name: 'Alee Khan',
      role: GroupRole.admin,
      logs: [
        _log(PrayerName.fajr, id: 'a1', at: _noon, url: link('alee-fajr')),
        _log(
          PrayerName.dhuhr,
          id: 'a2',
          at: _noon.add(const Duration(hours: 1)),
          url: link('alee-dhuhr'),
        ),
      ],
    ),
    GroupMemberPrayers(
      userId: 'member1',
      name: 'Sara Ahmed',
      role: GroupRole.member,
      logs: [
        _log(
          PrayerName.asr,
          id: 's1',
          at: _noon.add(const Duration(hours: 3)),
          url: link('sara-asr'),
        ),
        _log(
          PrayerName.maghrib,
          id: 's2',
          at: _noon.add(const Duration(hours: 6)),
          url: link('sara-maghrib'),
        ),
      ],
    ),
  ];
}

/// How many times the feed was read (the first read, plus each refresh).
var feedCalls = 0;

Future<void> _pump(
  WidgetTester tester, {
  Future<List<GroupMemberPrayers>> Function()? feed,
  double width = 390,
}) async {
  feedCalls = 0;
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(_Session.new),
        groupDetailProvider('g1').overrideWith((ref) async => _detail),
        groupPrayersProvider.overrideWith((ref, key) {
          feedCalls++;
          return (feed ?? () async => _feed())();
        }),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) =>
            const MaterialApp(home: GroupDetailScreen(groupId: 'g1')),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _labelled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

void main() {
  testWidgets('the "Today\'s prayers" section is gone', (tester) async {
    await _pump(tester);
    expect(find.text('Today’s prayers'), findsNothing);
    expect(find.text("Today's prayers"), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Snapped today" now lives in the header, once', (tester) async {
    await _pump(tester);
    expect(find.text('Snapped today'), findsOneWidget);
    expect(find.textMatching(r'^\d+ of 2 members$'), findsOneWidget);
    expect(find.text('day streak'), findsOneWidget);
    expect(find.textContaining('Longest streak'), findsOneWidget);

    // It sits inside the header block, above the Members list.
    final summary = tester.getTopLeft(find.text('Snapped today')).dy;
    final members = tester.getTopLeft(find.text('Members')).dy;
    expect(summary, lessThan(members));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the member cards no longer show the prayer circles', (
    tester,
  ) async {
    await _pump(tester);
    expect(_labelled('Fajr logged'), findsNothing);
    expect(_labelled('Fajr not logged'), findsNothing);
    expect(find.byType(PrayerDotsRow), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a member without a photo has a plain white box', (tester) async {
    await _pump(tester);
    expect(find.byType(SnapBox), findsNWidgets(2), reason: 'one per member');
    expect(
      find.descendant(
        of: find.byType(SnapBox),
        matching: find.byIcon(Icons.photo_camera_rounded),
      ),
      findsNothing,
      reason: 'no camera icon on the box',
    );
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SnapBox),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, Colors.white);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a member who sent a snap shows its picture in the box', (
    tester,
  ) async {
    await _pump(tester);
    final boxes = tester.widgetList<SnapBox>(find.byType(SnapBox));
    final withPhoto = boxes.where((b) => b.photoUrl != null).length;
    expect(withPhoto, lessThanOrEqualTo(1), reason: 'never on your own card');
    expect(
      find.descendant(
        of: find.byType(SnapBox),
        matching: find.byType(SnapPhoto),
      ),
      findsNWidgets(withPhoto),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each card shows snaps, score and day streak', (tester) async {
    await _pump(tester);
    // One row per member: camera + snaps, bolt + score, flame + "17d".
    expect(find.byIcon(Icons.photo_camera_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.bolt_rounded), findsNWidgets(2));
    expect(find.textMatching(r'^\d+d$'), findsNWidgets(2));
    // The header summary has its own flame, so 1 + one per member.
    expect(find.byIcon(Icons.local_fire_department_rounded), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the stats sit under the name on the card', (tester) async {
    await _pump(tester);
    final name = tester.getTopLeft(find.text('Sara Ahmed')).dy;
    final bolts = [
      for (final e in find.byIcon(Icons.bolt_rounded).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    expect(bolts.any((y) => y > name && y - name < 40), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('on a narrow phone nothing overflows', (tester) async {
    await _pump(tester, width: 320);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.bolt_rounded), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the stats do not depend on the prayer feed', (tester) async {
    await _pump(tester, feed: () async => throw const NetworkFailure());
    expect(find.byIcon(Icons.bolt_rounded), findsNWidgets(2));
    expect(find.textMatching(r'^\d+d$'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no circles while the feed is unavailable', (tester) async {
    await _pump(tester, feed: () async => throw const NetworkFailure());
    expect(find.textContaining('Alee Khan'), findsOneWidget);
    expect(_labelled('Fajr not logged'), findsNothing);
    expect(_labelled('Fajr logged'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('members are still listed with their details', (tester) async {
    await _pump(tester);
    expect(find.text('Sara Ahmed'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  group('hero summary', () {
    testWidgets('the week circles are gone, the rest stays', (tester) async {
      await _pump(tester);
      expect(find.text('Snapped today'), findsOneWidget);
      expect(find.textMatching(r'^\d+%$'), findsOneWidget);
      expect(find.text('day streak'), findsOneWidget);
      expect(find.textContaining('Longest streak'), findsOneWidget);
      // The week row used one letter per day (M T W T F S S).
      for (final letter in ['M', 'T', 'W', 'F', 'S']) {
        expect(find.text(letter), findsNothing, reason: 'week letter $letter');
      }
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('real photos', () {
    /// The white box on [name]'s card.
    Finder viewPhoto() => _labelled('View photo');
    Finder noPhoto() => _labelled('No photo');

    testWidgets('others\' boxes are enabled, the viewer\'s own is not', (
      tester,
    ) async {
      await _pump(tester);
      // Sara (someone else) has a photo to open; Alee (me) does not.
      expect(viewPhoto(), findsOneWidget);
      expect(noPhoto(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tapping someone else\'s box opens their latest photo', (
      tester,
    ) async {
      await _pump(tester);
      // The enabled box is Sara's (the viewer's own is disabled).
      await tester.tap(
        find
            .descendant(of: viewPhoto(), matching: find.byType(Container))
            .first,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(
        find.textContaining('Maghrib'),
        findsOneWidget,
        reason: 'her latest photo, not the older Asr one',
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the photo link is refreshed on tap', (tester) async {
      await _pump(tester);
      final before = feedCalls;
      await tester.tap(
        find
            .descendant(of: viewPhoto(), matching: find.byType(Container))
            .first,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(feedCalls, greaterThan(before), reason: 'signed links expire');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('your own box does nothing when tapped', (tester) async {
      await _pump(tester);
      await tester.tap(
        find.descendant(of: noPhoto(), matching: find.byType(Container)).first,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Close'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no photos in the feed: every box is plain', (tester) async {
      await _pump(tester, feed: () async => _feed(photos: false));
      expect(viewPhoto(), findsNothing);
      expect(noPhoto(), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('feed unavailable: boxes are plain too', (tester) async {
      await _pump(tester, feed: () async => throw const NetworkFailure());
      expect(viewPhoto(), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('when the refresh fails, the link already held is used', (
      tester,
    ) async {
      var first = true;
      await _pump(
        tester,
        feed: () async {
          if (first) {
            first = false;
            return _feed();
          }
          throw const NetworkFailure();
        },
      );
      await tester.tap(
        find
            .descendant(of: viewPhoto(), matching: find.byType(Container))
            .first,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
  group('member detail sheet: today\'s prayer circles', () {
    /// Opens a member's sheet (the viewer is the admin, so any member opens).
    Future<void> openSheet(WidgetTester tester, String name) async {
      await tester.tap(find.textContaining(name));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('shows the five circles with their names', (tester) async {
      await _pump(tester);
      await openSheet(tester, 'Sara Ahmed');
      expect(find.text('Today’s prayers'), findsOneWidget);
      for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      // Sara prayed Asr and Maghrib; the other three are open.
      expect(_labelled('Asr logged'), findsOneWidget);
      expect(_labelled('Maghrib logged'), findsOneWidget);
      expect(_labelled('Fajr not logged'), findsOneWidget);
      expect(_labelled('Dhuhr not logged'), findsOneWidget);
      expect(_labelled('Isha not logged'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sits above the stats in the sheet', (tester) async {
      await _pump(tester);
      await openSheet(tester, 'Sara Ahmed');
      final prayers = tester.getTopLeft(find.text('Today’s prayers')).dy;
      final snapActivity = tester.getTopLeft(find.text('Snap activity')).dy;
      expect(prayers, lessThan(snapActivity));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a circle with a photo opens it for someone else', (
      tester,
    ) async {
      await _pump(tester);
      await openSheet(tester, 'Sara Ahmed');
      await tester.tap(_labelled('Asr logged'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('Sara Ahmed · Asr'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('your own sheet shows progress but opens no photo', (
      tester,
    ) async {
      await _pump(tester);
      await openSheet(tester, 'Alee Khan');
      expect(_labelled('Fajr logged'), findsOneWidget);
      await tester.tap(_labelled('Fajr logged'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Close'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no circles section while the feed is unavailable', (
      tester,
    ) async {
      await _pump(tester, feed: () async => throw const NetworkFailure());
      await openSheet(tester, 'Sara Ahmed');
      expect(find.text('Today’s prayers'), findsNothing);
      expect(_labelled('Asr logged'), findsNothing);
      // The rest of the sheet is unaffected.
      expect(find.text('Snap activity'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

extension on CommonFinders {
  /// A [Text] whose whole content matches [pattern].
  Finder textMatching(String pattern) => byWidgetPredicate(
    (w) => w is Text && RegExp(pattern).hasMatch(w.data ?? ''),
  );
}
