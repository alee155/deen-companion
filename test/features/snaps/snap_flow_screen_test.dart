import 'dart:async';

import 'package:deen_companion/core/permissions/camera_permission_service.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/snaps/data/camera/camera_session.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:deen_companion/features/snaps/presentation/screens/snap_flow_screen.dart';
import 'package:deen_companion/features/snaps/presentation/widgets/crop_view.dart';
import 'package:deen_companion/features/snaps/presentation/widgets/shutter_button.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show CheckedState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'snap_fakes.dart';

class _Session extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'me', email: 'me@b.c', name: 'Me');
}

const _group = GroupDetail(
  id: 'g1',
  name: 'Namaz Family',
  members: [
    GroupMember(
      userId: 'me',
      name: 'Me Myself',
      email: 'me@b.c',
      role: GroupRole.admin,
    ),
    GroupMember(
      userId: 'u2',
      name: 'Sara Ahmed',
      email: 's@b.c',
      role: GroupRole.member,
    ),
    GroupMember(
      userId: 'u3',
      name: 'Omar Khan',
      email: 'o@b.c',
      role: GroupRole.member,
    ),
  ],
);

late FakeCameraService camera;
late FakeProcessor processor;
late FakeSnapRepository repo;

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  GroupDetail group = _group,
  List<Group> groups = sampleGroups,
  String? from = 'g1',
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  camera = FakeCameraService();
  processor = FakeProcessor();
  repo = FakeSnapRepository();

  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(_Session.new),
      groupDetailProvider('g1').overrideWith((ref) async => group),
      myGroupsProvider.overrideWith(() => FakeMyGroups(groups)),
      cameraServiceProvider.overrideWithValue(camera),
      snapImageProcessorProvider.overrideWithValue(processor),
      snapRepositoryProvider.overrideWithValue(repo),
      cameraPermissionServiceProvider.overrideWithValue(FakeCameraPermission()),
    ],
  );
  addTearDown(container.dispose);

  // The flow is pushed on top of a base route so a successful send can pop.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('GROUP SCREEN')),
      ),
      GoRoute(
        path: '/groups/:id/snap',
        builder: (_, s) =>
            SnapFlowScreen(initialGroupId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/snap', builder: (_, _) => const SnapFlowScreen()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  unawaited(router.push<int>(from == null ? '/snap' : '/groups/$from/snap'));
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Jumps the flow to the groups step via the real controller methods.
Future<void> _toGroups(
  WidgetTester tester,
  ProviderContainer c, {
  String? from = 'g1',
}) async {
  final n = c.read(snapComposerProvider(from).notifier);
  await n.onCaptured('/tmp/a.jpg');
  n.onCropped(tinyPng);
  await n.continueToGroups();
  await _settle(tester);
}

/// The checkbox on the row for [group].
Finder _boxFor(String group) => find.descendant(
  of: find.ancestor(of: find.text(group), matching: find.byType(InkWell)),
  matching: find.byType(Checkbox),
);

bool _ticked(WidgetTester tester, String group) =>
    tester.widget<Checkbox>(_boxFor(group)).value ?? false;

void main() {
  testWidgets('opens straight into the live camera (not a gallery)', (
    tester,
  ) async {
    await _pump(tester);
    expect(camera.opened, [SnapLens.back]);
    expect(find.text('Namaz Family'), findsOneWidget);
    expect(find.byType(ShutterButton), findsOneWidget);
    expect(find.byTooltip('Switch camera'), findsOneWidget);
    expect(find.byTooltip('Flash: off'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('flash button cycles and switch camera flips lens', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byTooltip('Flash: off'));
    await _settle(tester);
    expect(find.byTooltip('Flash: auto'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch camera'));
    await _settle(tester);
    expect(c.read(snapCameraControllerProvider).lens, SnapLens.front);
    // Front camera has no flash: the button is inert.
    expect(find.byTooltip('Flash: off'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('permission denied shows a helpful state with a way forward', (
    tester,
  ) async {
    camera = FakeCameraService()..problem = CameraProblem.denied;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_Session.new),
        groupDetailProvider('g1').overrideWith((ref) async => _group),
        myGroupsProvider.overrideWith(() => FakeMyGroups(sampleGroups)),
        cameraServiceProvider.overrideWithValue(camera),
        snapImageProcessorProvider.overrideWithValue(FakeProcessor()),
        snapRepositoryProvider.overrideWithValue(FakeSnapRepository()),
        cameraPermissionServiceProvider.overrideWithValue(
          FakeCameraPermission(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              const MaterialApp(home: SnapFlowScreen(initialGroupId: 'g1')),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Camera access needed'), findsOneWidget);
    expect(find.text('Allow camera'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('taking a photo moves to the crop step', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byType(ShutterButton));
    await _settle(tester);
    expect(processor.editCalls, 1);
    expect(c.read(snapComposerProvider('g1')).step, SnapStep.crop);
    expect(find.byType(CropView), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Square'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('preview step: timer chips change the viewing time', (
    tester,
  ) async {
    final c = await _pump(tester);
    final n = c.read(snapComposerProvider('g1').notifier);
    await n.onCaptured('/tmp/a.jpg');
    n.onCropped(tinyPng);
    await _settle(tester);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('5s'), findsWidgets);
    await tester.tap(find.text('10s'));
    await _settle(tester);
    expect(c.read(snapComposerProvider('g1')).viewSeconds, 10);
    await tester.pumpWidget(const SizedBox());
  });

  group('choosing groups', () {
    testWidgets('lists every group with a checkbox, and no members', (
      tester,
    ) async {
      final c = await _pump(tester);
      await _toGroups(tester, c);

      expect(find.text('Choose groups'), findsOneWidget);
      for (final g in ['Namaz Family', 'Quran Circle', 'Friday Friends']) {
        expect(find.text(g), findsWidgets);
        expect(_boxFor(g), findsOneWidget, reason: g);
      }
      // Counts, not people.
      expect(find.text('8 members'), findsOneWidget);
      expect(find.text('21 members'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('Sara Ahmed'), findsNothing);
      expect(find.text('Omar Khan'), findsNothing);
      expect(
        find.textContaining(
          'Everyone in the groups you choose receives this snap.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('opened from a group: that one is ticked, the rest are not', (
      tester,
    ) async {
      final c = await _pump(tester, from: 'g1');
      await _toGroups(tester, c);

      expect(_ticked(tester, 'Namaz Family'), isTrue);
      expect(_ticked(tester, 'Quran Circle'), isFalse);
      expect(_ticked(tester, 'Friday Friends'), isFalse);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Send to 1 group'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('opened from the list: nothing is ticked and Send waits', (
      tester,
    ) async {
      final c = await _pump(tester, from: null);
      await _toGroups(tester, c, from: null);

      for (final g in ['Namaz Family', 'Quran Circle', 'Friday Friends']) {
        expect(_ticked(tester, g), isFalse, reason: g);
      }
      expect(find.text('Choose a group'), findsOneWidget);
      final send = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Choose a group'),
      );
      expect(send.onPressed, isNull);
      expect(find.textContaining('selected'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tapping a checkbox or anywhere on the row ticks it', (
      tester,
    ) async {
      final c = await _pump(tester, from: null);
      await _toGroups(tester, c, from: null);

      await tester.tap(_boxFor('Quran Circle'));
      await tester.pump();
      expect(_ticked(tester, 'Quran Circle'), isTrue);

      await tester.tap(find.text('Friday Friends'));
      await tester.pump();
      expect(_ticked(tester, 'Friday Friends'), isTrue);
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Send to 2 groups'), findsOneWidget);

      await tester.tap(find.text('Quran Circle'));
      await tester.pump();
      expect(_ticked(tester, 'Quran Circle'), isFalse);
      expect(find.text('Send to 1 group'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Select all, then Clear', (tester) async {
      final c = await _pump(tester, from: null);
      await _toGroups(tester, c, from: null);

      await tester.tap(find.text('Select all'));
      await tester.pump();
      for (final g in ['Namaz Family', 'Quran Circle', 'Friday Friends']) {
        expect(_ticked(tester, g), isTrue, reason: g);
      }
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.text('Send to 3 groups'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      for (final g in ['Namaz Family', 'Quran Circle', 'Friday Friends']) {
        expect(_ticked(tester, g), isFalse, reason: g);
      }
      expect(find.text('Select all'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a single group has no Select all', (tester) async {
      final c = await _pump(tester, groups: [sampleGroups.first]);
      await _toGroups(tester, c);
      expect(find.text('Select all'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('screen readers hear name, size and whether it is ticked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await _pump(tester, from: 'g1');
      await _toGroups(tester, c);

      final node = tester.getSemantics(
        find.bySemanticsLabel('Namaz Family, 8 members'),
      );
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      final other = tester.getSemantics(
        find.bySemanticsLabel('Quran Circle, 21 members'),
      );
      expect(other.flagsCollection.isChecked, CheckedState.isFalse);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('sending', () {
    testWidgets('one group: sends to it and closes with a count of 1', (
      tester,
    ) async {
      final c = await _pump(tester, from: 'g1');
      final n = c.read(snapComposerProvider('g1').notifier);
      await n.onCaptured('/tmp/a.jpg');
      n.onCropped(tinyPng);
      n.setTimer(10);
      await n.continueToGroups();
      await _settle(tester);
      await tester.tap(find.text('Send to 1 group'));
      await _settle(tester);

      expect(repo.sent.single.groupIds, ['g1']);
      expect(repo.sent.single.viewSeconds, 10);
      expect(find.byType(SnapFlowScreen), findsNothing);
      expect(find.text('GROUP SCREEN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('several groups: one request naming all of them', (
      tester,
    ) async {
      final c = await _pump(tester, from: null);
      await _toGroups(tester, c, from: null);
      await tester.tap(find.text('Quran Circle'));
      await tester.tap(find.text('Friday Friends'));
      await tester.pump();
      await tester.tap(find.text('Send to 2 groups'));
      await _settle(tester);

      expect(repo.sent, hasLength(1));
      expect(repo.sent.single.groupIds, ['g2', 'g3']);
      expect(find.text('GROUP SCREEN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the flow closes with how many groups it went to', (
      tester,
    ) async {
      final c = await _pump(tester, from: null);
      await _toGroups(tester, c, from: null);
      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.text('Send to 3 groups'));
      await _settle(tester);
      // The page below received 3 (checked through the real entry helper in
      // snap_entry_test); here the flow itself is gone.
      expect(find.byType(SnapFlowScreen), findsNothing);
      expect(repo.sent.single.groupIds, hasLength(3));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failure keeps the flow open with the error and the ticks', (
      tester,
    ) async {
      final c = await _pump(tester, from: 'g1');
      await _toGroups(tester, c);
      repo.failure = serverFailure;
      await tester.tap(find.text('Send to 1 group'));
      await _settle(tester);

      expect(find.text('upload failed'), findsOneWidget);
      expect(find.byType(SnapFlowScreen), findsOneWidget);
      expect(_ticked(tester, 'Namaz Family'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a group left while taking the photo is not sent to', (
      tester,
    ) async {
      final c = await _pump(tester, from: 'g1');
      final n = c.read(snapComposerProvider('g1').notifier);
      n.setGroups(['g1', 'g-gone']);
      await _toGroups(tester, c);
      await tester.tap(find.text('Send to 1 group'));
      await _settle(tester);
      expect(repo.sent.single.groupIds, ['g1']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('back from the groups step returns to the preview', (
      tester,
    ) async {
      final c = await _pump(tester, from: 'g1');
      await _toGroups(tester, c);
      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(c.read(snapComposerProvider('g1')).step, SnapStep.edit);
      expect(c.read(snapComposerProvider('g1')).selectedGroupIds, {'g1'});
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('when the groups cannot be listed', () {
    testWidgets('a user in no group is told, and cannot send', (tester) async {
      final c = await _pump(tester, groups: const [], from: null);
      await _toGroups(tester, c, from: null);
      expect(find.text('You’re not in any group yet'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      final send = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Choose a group'),
      );
      expect(send.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the camera', () {
    testWidgets('from a group it is titled with the group', (tester) async {
      await _pump(tester, from: 'g1');
      expect(find.text('Namaz Family'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('from the list it is titled "New snap"', (tester) async {
      await _pump(tester, from: null);
      expect(find.text('New snap'), findsOneWidget);
      expect(camera.opened, [SnapLens.back]);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
