import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/permissions/camera_permission_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/camera/camera_session.dart';
import '../providers/snap_providers.dart';
import 'shutter_button.dart';
import 'snap_chrome.dart';

/// Step 1: live camera. Everything except local gestures (pinch, tap ring)
/// goes through [snapCameraControllerProvider].
class CaptureView extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final VoidCallback onClose;

  const CaptureView({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.onClose,
  });

  @override
  ConsumerState<CaptureView> createState() => _CaptureViewState();
}

class _CaptureViewState extends ConsumerState<CaptureView> {
  late final AppLifecycleListener _lifecycle;
  double _baseZoom = 1;
  Offset? _focusRing;
  bool _flashFrame = false;

  @override
  void initState() {
    super.initState();
    // Release the camera while backgrounded; reopen on return.
    _lifecycle = AppLifecycleListener(
      onInactive: () => ref.read(snapCameraControllerProvider.notifier).pause(),
      onResume: () => ref.read(snapCameraControllerProvider.notifier).resume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final path = await ref
        .read(snapCameraControllerProvider.notifier)
        .capture();
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t take the photo. Try again.')),
      );
      return;
    }
    setState(() => _flashFrame = true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _flashFrame = false);
    });
    await ref
        .read(snapComposerProvider(widget.groupId).notifier)
        .onCaptured(path);
  }

  @override
  Widget build(BuildContext context) {
    final cam = ref.watch(snapCameraControllerProvider);
    final composer = ref.watch(snapComposerProvider(widget.groupId));
    final busy = cam.isCapturing || composer.isProcessing;

    return SnapBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                children: [
                  SnapRoundButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close camera',
                    onPressed: widget.onClose,
                  ),
                  Expanded(
                    child: Center(
                      child: SnapPill(
                        icon: Icons.groups_rounded,
                        text: widget.groupName,
                      ),
                    ),
                  ),
                  SnapRoundButton(
                    icon: switch (cam.flash) {
                      SnapFlash.off => Icons.flash_off_rounded,
                      SnapFlash.auto => Icons.flash_auto_rounded,
                      SnapFlash.on => Icons.flash_on_rounded,
                    },
                    tooltip: 'Flash: ${cam.flash.name}',
                    active: cam.flash != SnapFlash.off,
                    onPressed: (cam.session?.hasFlash ?? false)
                        ? () => ref
                              .read(snapCameraControllerProvider.notifier)
                              .cycleFlash()
                        : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(child: _preview(cam)),
            SizedBox(height: 18.h),
            _controls(cam, busy),
            SizedBox(height: 14.h),
          ],
        ),
      ),
    );
  }

  Widget _preview(CameraUiState cam) {
    if (cam.problem != null) {
      return _Problem(
        problem: cam.problem!,
        onOpenSettings: () =>
            ref.read(cameraPermissionServiceProvider).openSettings(),
        onRetry: () => ref.read(snapCameraControllerProvider.notifier).retry(),
      );
    }
    final session = cam.session;
    if (session == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.emeraldInk),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Center(
        child: AspectRatio(
          aspectRatio: session.previewAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.r),
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) => _baseZoom = cam.zoom,
                onScaleUpdate: (d) {
                  if (d.pointerCount >= 2) {
                    ref
                        .read(snapCameraControllerProvider.notifier)
                        .setZoom(_baseZoom * d.scale);
                  }
                },
                onTapUp: (d) {
                  final p = Offset(
                    d.localPosition.dx / box.maxWidth,
                    d.localPosition.dy / box.maxHeight,
                  );
                  HapticFeedback.selectionClick();
                  setState(() => _focusRing = d.localPosition);
                  ref.read(snapCameraControllerProvider.notifier).focusAt(p);
                  Future<void>.delayed(const Duration(milliseconds: 700), () {
                    if (mounted) setState(() => _focusRing = null);
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    session.buildPreview(),
                    if (_focusRing != null)
                      Positioned(
                        left: _focusRing!.dx - 32,
                        top: _focusRing!.dy - 32,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.emeraldInk,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    if (cam.zoom > 1.05)
                      Positioned(
                        top: 12.h,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SnapPill(
                            text: '${cam.zoom.toStringAsFixed(1)}×',
                          ),
                        ),
                      ),
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _flashFrame ? 0.85 : 0,
                        duration: const Duration(milliseconds: 100),
                        child: const ColoredBox(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(CameraUiState cam, bool busy) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 56.w,
          child: Text(
            'Pinch\nto zoom',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.sp,
              height: 1.3,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        ShutterButton(busy: busy, onPressed: cam.isReady ? _capture : null),
        SizedBox(
          width: 56.w,
          child: Center(
            child: SnapRoundButton(
              icon: Icons.cameraswitch_rounded,
              tooltip: 'Switch camera',
              onPressed: cam.isReady && !busy
                  ? () => ref
                        .read(snapCameraControllerProvider.notifier)
                        .switchLens()
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  final CameraProblem problem;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  const _Problem({
    required this.problem,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (problem) {
      CameraProblem.denied => (
        Icons.no_photography_rounded,
        'Camera access needed',
        'Allow camera access to take a snap for your group.',
      ),
      CameraProblem.deniedForever => (
        Icons.no_photography_rounded,
        'Camera access is off',
        'Turn on the camera for Deen Companion in your phone’s settings.',
      ),
      CameraProblem.restricted => (
        Icons.lock_outline_rounded,
        'Camera is restricted',
        'This device doesn’t allow camera access for apps.',
      ),
      CameraProblem.unavailable => (
        Icons.videocam_off_rounded,
        'Camera unavailable',
        'We couldn’t open the camera. Close other apps using it and try again.',
      ),
    };
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52.sp, color: AppColors.emeraldInk),
            SizedBox(height: 14.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            SizedBox(height: 18.h),
            if (problem == CameraProblem.deniedForever)
              FilledButton(
                onPressed: onOpenSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emeraldInk,
                  foregroundColor: AppColors.onEmeraldInk,
                ),
                child: const Text('Open settings'),
              )
            else if (problem != CameraProblem.restricted)
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emeraldInk,
                  foregroundColor: AppColors.onEmeraldInk,
                ),
                child: Text(
                  problem == CameraProblem.denied
                      ? 'Allow camera'
                      : 'Try again',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
