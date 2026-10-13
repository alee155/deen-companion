import 'dart:typed_data';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/permissions/camera_permission_service.dart';
import 'package:deen_companion/features/snaps/data/camera/camera_session.dart';
import 'package:deen_companion/features/snaps/domain/entities/snap_draft.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'snap_fakes.dart';

void main() {
  late FakeCameraService camera;
  late FakeProcessor processor;
  late FakeSnapRepository repo;
  late FakeCameraPermission permission;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        cameraServiceProvider.overrideWithValue(camera),
        snapImageProcessorProvider.overrideWithValue(processor),
        snapRepositoryProvider.overrideWithValue(repo),
        cameraPermissionServiceProvider.overrideWithValue(permission),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    camera = FakeCameraService();
    processor = FakeProcessor();
    repo = FakeSnapRepository();
    permission = FakeCameraPermission();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('SnapCameraController', () {
    test('opens the back camera on start', () async {
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final s = c.read(snapCameraControllerProvider);
      expect(s.isReady, isTrue);
      expect(s.lens, SnapLens.back);
      expect(camera.opened, [SnapLens.back]);
    });

    test(
      'permission / availability problems become a state, not a crash',
      () async {
        for (final p in CameraProblem.values) {
          camera = FakeCameraService()..problem = p;
          final c = make();
          final sub = c.listen(snapCameraControllerProvider, (_, _) {});
          await settle();
          final s = c.read(snapCameraControllerProvider);
          expect(s.problem, p);
          expect(s.isReady, isFalse);
          expect(s.isOpening, isFalse);
          sub.close();
        }
      },
    );

    test(
      'denied + the OS will no longer ask → send them to Settings',
      () async {
        camera.problem = CameraProblem.denied;
        permission.permanentlyDenied = true;
        final c = make();
        final sub = c.listen(snapCameraControllerProvider, (_, _) {});
        addTearDown(sub.close);
        await settle();
        await settle();
        expect(
          c.read(snapCameraControllerProvider).problem,
          CameraProblem.deniedForever,
        );
      },
    );

    test('denied once (can still prompt) stays a plain denial', () async {
      camera.problem = CameraProblem.denied;
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      await settle();
      expect(
        c.read(snapCameraControllerProvider).problem,
        CameraProblem.denied,
      );
    });

    test('retry reopens after the user grants access', () async {
      camera.problem = CameraProblem.denied;
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      camera.problem = null;
      await c.read(snapCameraControllerProvider.notifier).retry();
      expect(c.read(snapCameraControllerProvider).isReady, isTrue);
      expect(c.read(snapCameraControllerProvider).problem, isNull);
    });

    test('switchLens closes the old camera and opens the other', () async {
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      await c.read(snapCameraControllerProvider.notifier).switchLens();
      expect(camera.opened, [SnapLens.back, SnapLens.front]);
      expect(camera.sessions.first.disposed, isTrue);
      expect(c.read(snapCameraControllerProvider).lens, SnapLens.front);
    });

    test('flash cycles off → auto → on → off, only when supported', () async {
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final n = c.read(snapCameraControllerProvider.notifier);
      await n.cycleFlash();
      expect(c.read(snapCameraControllerProvider).flash, SnapFlash.auto);
      await n.cycleFlash();
      expect(c.read(snapCameraControllerProvider).flash, SnapFlash.on);
      expect(camera.sessions.first.flash, SnapFlash.on);
      await n.cycleFlash();
      expect(c.read(snapCameraControllerProvider).flash, SnapFlash.off);

      await n.switchLens(); // front camera has no flash
      await n.cycleFlash();
      expect(c.read(snapCameraControllerProvider).flash, SnapFlash.off);
    });

    test('zoom is clamped to the camera range', () async {
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final n = c.read(snapCameraControllerProvider.notifier);
      await n.setZoom(10);
      expect(c.read(snapCameraControllerProvider).zoom, 4);
      await n.setZoom(0.2);
      expect(c.read(snapCameraControllerProvider).zoom, 1);
    });

    test('capture returns the photo path and clears the busy flag', () async {
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final path = await c
          .read(snapCameraControllerProvider.notifier)
          .capture();
      expect(path, '/tmp/fake_capture_1.jpg');
      expect(c.read(snapCameraControllerProvider).isCapturing, isFalse);
    });

    test('pause releases the camera, resume reopens it', () async {
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final n = c.read(snapCameraControllerProvider.notifier);
      await n.pause();
      expect(camera.sessions.first.disposed, isTrue);
      expect(c.read(snapCameraControllerProvider).session, isNull);
      await n.resume();
      expect(c.read(snapCameraControllerProvider).isReady, isTrue);
      expect(camera.opened.length, 2);
    });

    test('leaving the screen releases the camera', () async {
      final c = make();
      final sub = c.listen(snapCameraControllerProvider, (_, _) {});
      await settle();
      sub.close();
      await settle();
      c.invalidate(snapCameraControllerProvider);
      expect(camera.sessions.first.disposed, isTrue);
    });
  });

  group('SnapComposerController', () {
    ProviderContainer open() {
      final c = make();
      final sub = c.listen(snapComposerProvider('g1'), (_, _) {});
      addTearDown(sub.close);
      return c;
    }

    test('starts at the camera with the default 5s timer', () {
      final s = open().read(snapComposerProvider('g1'));
      expect(s.step, SnapStep.capture);
      expect(s.viewSeconds, SnapViewTimer.defaultSeconds);
    });

    test('capture → crop: prepares the photo for editing', () async {
      final c = open();
      await c
          .read(snapComposerProvider('g1').notifier)
          .onCaptured('/tmp/a.jpg');
      final s = c.read(snapComposerProvider('g1'));
      expect(s.step, SnapStep.crop);
      expect(s.source, isNotNull);
      expect(s.isProcessing, isFalse);
      expect(processor.editCalls, 1);
    });

    test('unreadable photo stays on the camera with an error', () async {
      processor.editFailure = const UnexpectedFailure(
        'Couldn’t read the photo.',
      );
      final c = open();
      await c
          .read(snapComposerProvider('g1').notifier)
          .onCaptured('/tmp/a.jpg');
      final s = c.read(snapComposerProvider('g1'));
      expect(s.step, SnapStep.capture);
      expect(s.errorMessage, 'Couldn’t read the photo.');
    });

    test(
      'crop → edit, timer + caption, retake keeps the chosen timer',
      () async {
        final c = open();
        final n = c.read(snapComposerProvider('g1').notifier);
        await n.onCaptured('/tmp/a.jpg');
        n.onCropped(Uint8List.fromList([9]));
        expect(c.read(snapComposerProvider('g1')).step, SnapStep.edit);
        n.setTimer(15);
        n.setCaption('  Fajr  ');
        n.retake();
        final s = c.read(snapComposerProvider('g1'));
        expect(s.step, SnapStep.capture);
        expect(s.cropped, isNull);
        expect(s.source, isNull);
        expect(s.viewSeconds, 15);
      },
    );

    test(
      'Next compresses once; going back and forth does not recompress',
      () async {
        final c = open();
        final n = c.read(snapComposerProvider('g1').notifier);
        await n.onCaptured('/tmp/a.jpg');
        n.onCropped(Uint8List.fromList([9]));
        await n.continueToRecipients();
        expect(c.read(snapComposerProvider('g1')).step, SnapStep.recipients);
        expect(
          c.read(snapComposerProvider('g1')).prepared!.compressedBytes,
          1000,
        );
        n.backToEdit();
        await n.continueToRecipients();
        expect(processor.compressCalls, 1);
      },
    );

    test('re-cropping invalidates the compressed file', () async {
      final c = open();
      final n = c.read(snapComposerProvider('g1').notifier);
      await n.onCaptured('/tmp/a.jpg');
      n.onCropped(Uint8List.fromList([9]));
      await n.continueToRecipients();
      n.backToEdit();
      n.recrop();
      n.onCropped(Uint8List.fromList([8]));
      expect(c.read(snapComposerProvider('g1')).prepared, isNull);
      await n.continueToRecipients();
      expect(processor.compressCalls, 2);
    });

    test('compression failure stays on the preview with a message', () async {
      processor.compressFailure = const UnexpectedFailure(
        'Couldn’t prepare the photo.',
      );
      final c = open();
      final n = c.read(snapComposerProvider('g1').notifier);
      await n.onCaptured('/tmp/a.jpg');
      n.onCropped(Uint8List.fromList([9]));
      await n.continueToRecipients();
      final s = c.read(snapComposerProvider('g1'));
      expect(s.step, SnapStep.edit);
      expect(s.errorMessage, 'Couldn’t prepare the photo.');
    });

    test(
      'send hands the repository the full draft (and the flow stays on recipients for the screen to close)',
      () async {
        final c = open();
        final n = c.read(snapComposerProvider('g1').notifier);
        await n.onCaptured('/tmp/a.jpg');
        n.onCropped(Uint8List.fromList([9]));
        n.setTimer(10);
        n.setCaption('  Surah Al-Mulk ');
        await n.continueToRecipients();
        final ok = await n.send(['u2', 'u3']);
        expect(ok, isTrue);
        expect(c.read(snapComposerProvider('g1')).isSending, isFalse);
        final d = repo.sent.single;
        expect(d.groupId, 'g1'); // dynamic, from the route
        expect(d.imagePath, '/tmp/prepared.jpg');
        expect(d.viewSeconds, 10);
        expect(d.caption, 'Surah Al-Mulk');
        expect(d.recipientIds, ['u2', 'u3']);
      },
    );

    test('empty caption is sent as null', () async {
      final c = open();
      final n = c.read(snapComposerProvider('g1').notifier);
      await n.onCaptured('/tmp/a.jpg');
      n.onCropped(Uint8List.fromList([9]));
      n.setCaption('   ');
      await n.continueToRecipients();
      await n.send(['u2']);
      expect(repo.sent.single.caption, isNull);
    });

    test('send failure keeps the user on recipients with the error', () async {
      repo.failure = serverFailure;
      final c = open();
      final n = c.read(snapComposerProvider('g1').notifier);
      await n.onCaptured('/tmp/a.jpg');
      n.onCropped(Uint8List.fromList([9]));
      await n.continueToRecipients();
      expect(await n.send(['u2']), isFalse);
      final s = c.read(snapComposerProvider('g1'));
      expect(s.step, SnapStep.recipients);
      expect(s.errorMessage, 'upload failed');
      expect(s.isSending, isFalse);
      // retry works
      repo.failure = null;
      expect(await n.send(['u2']), isTrue);
    });

    test('temp files are cleaned up when the flow closes', () async {
      final c = make();
      final sub = c.listen(snapComposerProvider('g1'), (_, _) {});
      final n = c.read(snapComposerProvider('g1').notifier);
      await n.onCaptured('/tmp/a.jpg');
      n.onCropped(Uint8List.fromList([9]));
      await n.continueToRecipients();
      sub.close();
      c.invalidate(snapComposerProvider('g1'));
      await settle();
      expect(
        processor.cleaned,
        containsAll(['/tmp/a.jpg', '/tmp/prepared.jpg']),
      );
    });
  });
}
