import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import '../../prayer_logs/presentation/_prayer_log_test_support.dart';
import 'package:deen_companion/features/group_live/presentation/providers/group_live_store.dart';
import 'package:deen_companion/features/prayer_logs/presentation/widgets/snap_photo_viewer.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/groups/presentation/widgets/snap_widgets.dart';
import 'package:deen_companion/features/groups/presentation/widgets/group_detail_widgets.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/widgets/prayer_dots_row.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deen_companion/features/streaks/domain/entities/group_streaks.dart';
import '../../streaks/_streaks_support.dart';
import '../../group_live/_live_support.dart';

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
  snapUrl: null,
  // Other members' snaps carry no link: the flag says one is there to open.
  hasSnap: url != null,
  windowStartsAt: DateTime.now().subtract(const Duration(hours: 1)),
  windowEndsAt: DateTime.now().add(const Duration(hours: 1)),
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

/// Opens snaps like the server would; everything else fails as the network
/// did before these tests had a repository of their own.
class _ViewRepo extends ScriptedLogsRepo {
  _ViewRepo() {
    viewResult = const Success(OpenedSnap(url: 'https://img.test/x.jpg'));
  }

  @override
  Future<Result<CurrentPrayerState>> getCurrent() async =>
      const Error(NetworkFailure());
}

Future<void> _pump(
  WidgetTester tester, {
  Future<List<GroupMemberPrayers>> Function()? feed,
  FakeStreaksRepo? streaks,
  double width = 390,
  List<Override> overrides = const [],
}) async {
  feedCalls = 0;
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        groupSummaryRemoteDataSourceProvider.overrideWithValue(
          FakeSummaryRemote(),
        ),
        authSessionProvider.overrideWith(_Session.new),
        groupDetailProvider('g1').overrideWith((ref) async => _detail),
        streaksRepositoryProvider.overrideWithValue(
          streaks ?? FakeStreaksRepo(),
        ),
        prayerLogsRepositoryProvider.overrideWithValue(_ViewRepo()),
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

  testWidgets('the header shows how many met today\'s goal, from the board', (
    tester,
  ) async {
    await _pump(tester);
    // Default board: Alee met the goal, Sara has not.
    expect(find.text('Goal met today'), findsOneWidget);
    expect(find.text('1 of 2 members'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('top run'), findsOneWidget);
    expect(find.text('Longest streak: 9 days'), findsOneWidget);

    // It sits inside the header block, above the Members list.
    final summary = tester.getTopLeft(find.text('Goal met today')).dy;
    final members = tester.getTopLeft(find.text('Members')).dy;
    expect(summary, lessThan(members));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('there is no separate streak card: it is all in the rows', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('PRAYER STREAK'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no sample data is left on the screen', (tester) async {
    await _pump(tester);
    expect(find.text('SAMPLE DATA'), findsNothing);
    expect(find.text('Snapped today'), findsNothing);
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('your own row offers "send to more groups" only when possible', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byTooltip('Send your snap to more groups'), findsNothing);
    await tester.pumpWidget(const SizedBox());

    await _pump(
      tester,
      overrides: [
        addableSnapLogProvider.overrideWithValue(
          _log(PrayerName.asr, id: 'mine', at: _noon, url: 'x'),
        ),
      ],
    );
    // Only your own row has it (the other member's row has the ⋯ menu).
    expect(find.byTooltip('Send your snap to more groups'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the member who snapped most recently is on top', (tester) async {
    // The board puts Alee first; Sara's snap is the newer one, so she leads.
    await _pump(tester);
    final sara = tester.getTopLeft(find.text('Sara Ahmed')).dy;
    final alee = tester.getTopLeft(find.textContaining('Alee Khan')).dy;
    expect(sara, lessThan(alee));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a newer snap beats a longer streak', (tester) async {
    final repo = FakeStreaksRepo()
      ..board = Success(
        GroupStreakBoard([
          entry('admin1', name: 'Alee Khan', current: 30, best: 30),
          entry('member1', name: 'Sara Ahmed', current: 1, best: 1),
        ]),
      );
    await _pump(tester, streaks: repo);
    final sara = tester.getTopLeft(find.text('Sara Ahmed')).dy;
    final alee = tester.getTopLeft(find.textContaining('Alee Khan')).dy;
    expect(sara, lessThan(alee));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with no snaps, members follow the streak board', (tester) async {
    await _pump(tester, feed: () async => _feed(photos: false));
    // Board order is Alee (4) then Sara (2), the detail order is the same, so
    // flip the board to prove the board wins.
    await tester.pumpWidget(const SizedBox());
    final repo = FakeStreaksRepo()
      ..board = Success(
        GroupStreakBoard([
          entry('member1', name: 'Sara Ahmed', current: 9, best: 9),
          entry('admin1', name: 'Alee Khan', current: 1, best: 1),
        ]),
      );
    await _pump(tester, streaks: repo, feed: () async => _feed(photos: false));
    final sara = tester.getTopLeft(find.text('Sara Ahmed')).dy;
    final alee = tester.getTopLeft(find.textContaining('Alee Khan')).dy;
    expect(sara, lessThan(alee));
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

  Finder snapIcon(String asset) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == asset,
  );

  testWidgets('each member has a snap icon, drawn from the app images', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(SnapBox), findsNWidgets(2), reason: 'one per member');
    expect(
      find.descendant(
        of: find.byType(SnapBox),
        matching: find.byType(SnapPhoto),
      ),
      findsNothing,
      reason: 'no photo preview on the card any more',
    );
    expect(
      snapIcon(snapPendingAsset).evaluate().length +
          snapIcon(snapViewedAsset).evaluate().length,
      2,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a snap to open shows the filled arrow, none the outline', (
    tester,
  ) async {
    await _pump(tester);
    // Sara sent photos, so Alee (the viewer) has one to open on her card; his
    // own card has nothing to open.
    expect(snapIcon(snapPendingAsset), findsOneWidget);
    expect(snapIcon(snapViewedAsset), findsOneWidget);

    final aleeRow = find.ancestor(
      of: find.textContaining('Alee Khan'),
      matching: find.byType(MemberSnapTile),
    );
    final saraRow = find.ancestor(
      of: find.text('Sara Ahmed'),
      matching: find.byType(MemberSnapTile),
    );
    expect(
      find.descendant(of: aleeRow, matching: snapIcon(snapViewedAsset)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: saraRow, matching: snapIcon(snapPendingAsset)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nobody has a snap: every icon is the outlined one', (
    tester,
  ) async {
    await _pump(tester, feed: () async => _feed(photos: false));
    expect(snapIcon(snapPendingAsset), findsNothing);
    expect(snapIcon(snapViewedAsset), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each card shows prayers today, points and the streak', (
    tester,
  ) async {
    await _pump(tester);
    // Alee logged Fajr + Dhuhr, Sara Asr + Maghrib: 2 prayers, 10 points each.
    expect(find.text('2/5'), findsNWidgets(2));
    expect(find.byIcon(Icons.bolt_rounded), findsNWidgets(2));
    expect(find.text('10'), findsNWidgets(2));
    // Streaks from the board: Alee 4, Sara 2.
    expect(find.text('4d'), findsOneWidget);
    expect(find.text('2d'), findsOneWidget);
    // Flames: the header summary, and one per member.
    expect(find.byIcon(Icons.local_fire_department_rounded), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the figures sit under the name on the card', (tester) async {
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

  testWidgets('each figure shows once its own source has loaded', (
    tester,
  ) async {
    // Feed down: no prayers/points, but the board's streak still shows.
    await _pump(tester, feed: () async => throw const NetworkFailure());
    expect(find.text('2/5'), findsNothing);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
    expect(find.text('4d'), findsOneWidget);
    expect(find.text('2d'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('board down: prayers and points show, the streak does not', (
    tester,
  ) async {
    await _pump(
      tester,
      streaks: FakeStreaksRepo()..board = const Error(NetworkFailure()),
    );
    expect(find.text('2/5'), findsNWidgets(2));
    expect(find.text('4d'), findsNothing);
    expect(find.text('Goal met today'), findsNothing);
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
  group('real photos', () {
    /// The white box on [name]'s card.
    Finder viewPhoto() => _labelled('View snap');
    Finder noPhoto() => _labelled('No snap');

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
        find.descendant(of: viewPhoto(), matching: find.byType(Image)).first,
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
        find.descendant(of: viewPhoto(), matching: find.byType(Image)).first,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(feedCalls, greaterThan(before), reason: 'signed links expire');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('your own box does nothing when tapped', (tester) async {
      await _pump(tester);
      await tester.tap(
        find.descendant(of: noPhoto(), matching: find.byType(Image)).first,
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
        find.descendant(of: viewPhoto(), matching: find.byType(Image)).first,
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
      final stats = tester.getTopLeft(find.text('Day streak')).dy;
      expect(prayers, lessThan(stats));
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
      // The rest of the sheet is unaffected: the streak still shows, the
      // points (which come from the feed) do not.
      expect(find.text('Day streak'), findsOneWidget);
      expect(find.text('Points today'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
