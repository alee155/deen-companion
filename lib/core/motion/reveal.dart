import 'package:flutter/widgets.dart';

import 'motion_scope.dart';
import 'motion_tokens.dart';

/// One-shot entrance: fade + rise (and optional scale) that settles and then
/// costs nothing.
///
/// Performance notes:
///  * one controller per instance; the optional [delay] is folded into the
///    controller's timeline (no timers to leak);
///  * only transition widgets animate, so [child] is never rebuilt;
///  * skipped entirely when motion is reduced or the enclosing scrollable is
///    flinging (`recommendDeferredLoading`), so fast scrolling through long
///    lists never piles up animations.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.curve = AppMotion.entrance,
    this.rise = AppMotion.riseSmall,
    this.scaleFrom = 1.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  /// Vertical travel as a fraction of the child's height (0 = none).
  final double rise;

  /// Starting scale (1 = no scale).
  final double scaleFrom;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<Offset>? _slide;
  Animation<double>? _scale;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final motion = MotionScope.of(context);
    if (motion.reduced || Scrollable.recommendDeferredLoadingForContext(context)) {
      return; // show immediately
    }

    final total = widget.delay + widget.duration;
    final controller = AnimationController(vsync: this, duration: total);
    final begin = total.inMicroseconds == 0
        ? 0.0
        : widget.delay.inMicroseconds / total.inMicroseconds;
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, 1, curve: widget.curve),
    );
    _fade = curved;
    final rise = motion.distance(widget.rise);
    if (rise > 0) {
      _slide = Tween<Offset>(
        begin: Offset(0, rise),
        end: Offset.zero,
      ).animate(curved);
    }
    if (widget.scaleFrom != 1.0) {
      _scale = Tween<double>(begin: widget.scaleFrom, end: 1).animate(curved);
    }
    _controller = controller..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = _fade;
    if (fade == null) return widget.child;
    Widget result = widget.child;
    if (_scale != null) result = ScaleTransition(scale: _scale!, child: result);
    if (_slide != null) result = SlideTransition(position: _slide!, child: result);
    return FadeTransition(opacity: fade, child: result);
  }
}

/// Entrance helpers. Names kept from the previous motion layer so existing
/// call sites keep working.
extension AppEntranceAnimation on Widget {
  /// Standalone block appearing once (hero cards, sections).
  Widget appear({Key? key, Duration delay = Duration.zero}) => Reveal(
    key: key,
    delay: delay,
    rise: AppMotion.riseSmall,
    child: this,
  );

  /// List/grid item; pass its index to cascade (capped, see
  /// [AppMotion.staggerCap]).
  Widget appearStaggered(int index, {int maxIndex = AppMotion.staggerCap}) =>
      Reveal(
        delay: AppMotion.stagger(index, maxIndex: maxIndex),
        duration: AppMotion.fast + const Duration(milliseconds: 40),
        rise: AppMotion.rise,
        child: this,
      );

  /// Scale-in for dense icon grids where a vertical slide looks odd.
  Widget popIn({Key? key, Duration delay = Duration.zero}) => Reveal(
    key: key,
    delay: delay,
    duration: AppMotion.fast + const Duration(milliseconds: 40),
    rise: 0,
    scaleFrom: 0.9,
    child: this,
  );

  /// Celebratory scale-in with a single gentle overshoot (success marks).
  Widget celebrate({Key? key, Duration delay = Duration.zero}) => Reveal(
    key: key,
    delay: delay,
    duration: AppMotion.value,
    curve: AppMotion.pop,
    rise: 0,
    scaleFrom: 0.5,
    child: this,
  );
}
