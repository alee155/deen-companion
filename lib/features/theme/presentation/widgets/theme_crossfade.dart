import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// Makes a change of [ThemeVariant] look like one soft fade instead of a jump.
///
/// Two jobs, both needed because [AppColors] is read from a static palette:
///  1. **Rebuild once.** Widgets that read `AppColors` don't depend on any
///     inherited widget, so changing the palette alone leaves them stale. When
///     [variant] changes, every element below is marked dirty in the same
///     frame — state is kept (no remount, so no lost scroll or navigation).
///  2. **Fade.** Just before that rebuild, the old look is captured as an image
///     and laid over the new one, fading out. One rebuild plus one opacity
///     animation: no per-frame tree rebuilds.
///
/// The fade is skipped when the OS or the app asks for reduced motion.
class ThemeCrossfade extends StatefulWidget {
  const ThemeCrossfade({
    super.key,
    required this.variant,
    required this.child,
    this.duration = const Duration(milliseconds: 700),
  });

  final ThemeVariant variant;
  final Widget child;
  final Duration duration;

  @override
  State<ThemeCrossfade> createState() => _ThemeCrossfadeState();
}

class _ThemeCrossfadeState extends State<ThemeCrossfade>
    with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onFadeStatus);

  ui.Image? _snapshot;

  @override
  void didUpdateWidget(ThemeCrossfade old) {
    super.didUpdateWidget(old);
    if (old.variant == widget.variant) return;
    _captureOldLook();
    _markSubtreeDirty();
  }

  /// Grabs the frame as last painted — still the old look at this point, since
  /// the rebuild below hasn't run yet. Taken synchronously so the old look is
  /// already covering the screen on the very frame the new palette arrives: an
  /// async capture would let the new look show for a few frames, then the old
  /// one pop back over it, which reads as a flicker. Failure (or reduced
  /// motion) just means no fade; the switch itself still happens.
  void _captureOldLook() {
    if (context.motion.reduced) return;
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) return;
      final image = boundary.toImageSync(
        pixelRatio: View.of(context).devicePixelRatio,
      );
      _snapshot?.dispose();
      // No setState: this runs inside didUpdateWidget, build follows.
      _snapshot = image;
      _fade.forward(from: 0);
    } catch (_) {
      // Debug-only "needs paint" assertion or a missing layer: skip the fade.
    }
  }

  void _markSubtreeDirty() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _snapshot?.dispose();
      _snapshot = null;
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: ReverseAnimation(_fade),
                child: RawImage(image: snapshot, fit: BoxFit.fill),
              ),
            ),
          ),
      ],
    );
  }
}
