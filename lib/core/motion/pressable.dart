import 'package:flutter/widgets.dart';

import 'haptics.dart';
import 'motion_scope.dart';
import 'motion_tokens.dart';

/// Press-and-release scale feedback that does **not** take part in the
/// gesture arena — it listens to raw pointer events, so it can wrap an
/// `InkWell`, `GestureDetector` or button without changing their behaviour.
///
/// The scale is cancelled as soon as the finger drifts past [slop], so
/// scrolling a list of cards never leaves one stuck shrunken.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = AppMotion.pressScale,
    this.enabled = true,
    this.slop = 12,
  });

  final Widget child;
  final double scale;
  final bool enabled;
  final double slop;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.release,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.scale,
  ).animate(_controller);
  Offset? _down;

  void _press(PointerDownEvent e) {
    if (!widget.enabled || context.motion.reduced) return;
    _down = e.position;
    _controller.animateTo(
      1,
      duration: AppMotion.instant,
      curve: Curves.easeOut,
    );
  }

  void _release() {
    if (_down == null) return;
    _down = null;
    _controller.animateBack(
      0,
      duration: AppMotion.release,
      curve: AppMotion.entrance,
    );
  }

  void _move(PointerMoveEvent e) {
    final down = _down;
    if (down != null && (e.position - down).distance > widget.slop) _release();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _press,
      onPointerMove: _move,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Tappable surface with press feedback and optional haptics. Drop-in for
/// `GestureDetector(onTap: …)` on cards, tiles and custom buttons.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.haptic = false,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// Light haptic tick on tap. Off by default; enable for primary actions,
  /// toggles and counters.
  final bool haptic;
  final HitTestBehavior behavior;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onLongPress != null;
    Widget result = GestureDetector(
      behavior: behavior,
      onTap: onTap == null
          ? null
          : () {
              if (haptic) AppHaptics.selection();
              onTap!();
            },
      onLongPress: onLongPress == null
          ? null
          : () {
              AppHaptics.tap();
              onLongPress!();
            },
      child: PressScale(scale: scale, enabled: enabled, child: child),
    );
    if (semanticLabel != null) {
      result = Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: onTap,
        child: result,
      );
    }
    return result;
  }
}
