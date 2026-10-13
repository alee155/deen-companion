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

const _alone = GroupDetail(
  id: 'g1',
  name: 'Solo',
  members: [
    GroupMember(
      userId: 'me',
      name: 'Me Myself',
      email: 'me@b.c',
      role: GroupRole.admin,
    ),
  ],
);

late FakeCameraService camera;
late FakeProcessor processor;
late FakeSnapRepository repo;

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  GroupDetail group = _group,
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
        builder: (_, s) => SnapFlowScreen(groupId: s.pathParameters['id']!),
      ),
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
  router.push('/groups/g1/snap');
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Jumps the flow to the recipients step via the real controller methods.
Future<void> _toRecipients(WidgetTester tester, ProviderContainer c) async {
  final n = c.read(snapComposerProvider('g1').notifier);
  await n.onCaptured('/tmp/a.jpg');
  n.onCropped(tinyPng);
  await n.continueToRecipients();
  await _settle(tester);
}

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
              const MaterialApp(home: SnapFlowScreen(groupId: 'g1')),
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
    await tester.tap(find.text('15s'));
    await _settle(tester);
    expect(c.read(snapComposerProvider('g1')).viewSeconds, 15);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recipients: whole group, read-only, nothing to toggle', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _toRecipients(tester, c);
    expect(find.text('Sending to Namaz Family'), findsOneWidget);
    expect(find.text('Sara Ahmed'), findsOneWidget);
    expect(find.text('Omar Khan'), findsOneWidget);
    expect(
      find.text('Me Myself'),
      findsNothing,
    ); // the sender isn't a recipient
    expect(
      find.text('Everyone in the group receives this snap.'),
      findsOneWidget,
    );
    // No controls that could deselect anyone.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    await tester.tap(find.text('Sara Ahmed'));
    await _settle(tester);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('send delivers to every other member, then closes the flow', (
    tester,
  ) async {
    final c = await _pump(tester);
    final n = c.read(snapComposerProvider('g1').notifier);
    await n.onCaptured('/tmp/a.jpg');
    n.onCropped(tinyPng);
    n.setTimer(10);
    await n.continueToRecipients();
    await _settle(tester);
    await tester.tap(find.text('Send to 2 members'));
    await _settle(tester);
    expect(repo.sent.single.recipientIds, ['u2', 'u3']);
    expect(repo.sent.single.groupId, 'g1');
    expect(repo.sent.single.viewSeconds, 10);
    // No "Snap sent" screen: straight back to where the user came from.
    expect(find.text('Snap sent'), findsNothing);
    expect(find.byType(SnapFlowScreen), findsNothing);
    expect(find.text('GROUP SCREEN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('send failure keeps the flow open with the error', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _toRecipients(tester, c);
    repo.failure = serverFailure;
    await tester.tap(find.text('Send to 2 members'));
    await _settle(tester);
    expect(find.text('upload failed'), findsOneWidget);
    expect(find.byType(SnapFlowScreen), findsOneWidget); // stays open to retry
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a group with nobody else cannot send', (tester) async {
    final c = await _pump(tester, group: _alone);
    await _toRecipients(tester, c);
    expect(find.text('No one else is in this group yet'), findsOneWidget);
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send snap'),
    );
    expect(send.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
