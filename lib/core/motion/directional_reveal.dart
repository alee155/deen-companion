import 'package:flutter/widgets.dart';

import 'motion_scope.dart';
import 'motion_tokens.dart';

/// Where an element enters from.
enum RevealDirection {
  left,
  right,
  top,
  bottom,

  /// Reading-direction aware: `start` is left in LTR and right in RTL.
  start,
  end,

  /// Diagonals (reading-direction aware horizontally).
  topStart,
  topEnd,
  bottomStart,
  bottomEnd,

  /// Fade only.
  none,
}

/// Slides (and optionally fades) a widget in from a chosen [direction].
/// Built for text — headings, subtitles, labels, values — but works on any
/// widget.
///
/// * one-shot: plays once, then costs nothing;
/// * pixel-based [distance] so a wide heading and a short label travel the
///   same, small amount;
/// * only translate + opacity animate — [child] never rebuilds;
/// * skipped under reduced motion and while the enclosing scrollable is
///   flinging, so it never delays reading or interaction;
/// * with [onVisible], elements below the fold wait and play when they
///   scroll into view (one cheap listener that removes itself).
///
/// Choreograph several with [RevealSequence].
class DirectionalTextReveal extends StatefulWidget {
  const DirectionalTextReveal({
    super.key,
    required this.child,
    this.direction = RevealDirection.bottom,
    this.duration = AppMotion.slow,
    this.delay = Duration.zero,
    this.curve = AppMotion.emphasized,
    this.fade = true,
    this.distance = 24,
    this.onVisible = false,
  });

  final Widget child;
  final RevealDirection direction;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  /// Fade in while sliding. Turn off for a pure slide (text over busy
  /// images, or clipped by a parent).
  final bool fade;

  /// Travel in logical pixels (scaled by the app's motion level).
  final double distance;

  /// Wait until scrolled into view before playing. Use for anything that
  /// may start below the fold inside a scroll view.
  final bool onVisible;

  @override
  State<DirectionalTextReveal> createState() => _DirectionalTextRevealState();
}

class _DirectionalTextRevealState extends State<DirectionalTextReveal>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _progress;
  Offset _from = Offset.zero;
  bool _decided = false;
  bool _waiting = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final motion = MotionScope.of(context);
    if (motion.reduced) return; // show immediately

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final d = motion.distance(widget.distance);
    final dx = rtl ? -d : d; // "end" offset
    final dy = d * 0.6;
    _from = switch (widget.direction) {
      RevealDirection.left => Offset(-d, 0),
      RevealDirection.right => Offset(d, 0),
      RevealDirection.top => Offset(0, -d),
      RevealDirection.bottom => Offset(0, d),
      RevealDirection.start => Offset(-dx, 0),
      RevealDirection.end => Offset(dx, 0),
      RevealDirection.topStart => Offset(-dx * 0.7, -dy),
      RevealDirection.topEnd => Offset(dx * 0.7, -dy),
      RevealDirection.bottomStart => Offset(-dx * 0.7, dy),
      RevealDirection.bottomEnd => Offset(dx * 0.7, dy),
      RevealDirection.none => Offset.zero,
    };

    if (widget.onVisible && Scrollable.maybeOf(context) != null) {
      _waiting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _watch());
    } else if (!Scrollable.recommendDeferredLoadingForContext(context)) {
      _play();
    }
  }

  void _play() {
    final total = widget.delay + widget.duration;
    final controller = AnimationController(vsync: this, duration: total);
    final begin = widget.delay.inMicroseconds / total.inMicroseconds;
    _progress = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, 1, curve: widget.curve),
    );
    _controller = controller..forward();
  }

  // ── on-visible support ────────────────────────────────────────────────
  void _watch() {
    if (!mounted || !_waiting) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return _trigger();
    if (_isVisible(scrollable)) return _trigger();
    _position = scrollable.position..addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null && _isVisible(scrollable)) _trigger();
  }

  bool _isVisible(ScrollableState scrollable) {
    final box = context.findRenderObject();
    final viewport = scrollable.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.attached ||
        !viewport.attached ||
        !box.hasSize) {
      return false;
    }
    final horizontal = axisDirectionToAxis(scrollable.axisDirection) ==
        Axis.horizontal;
    final origin = box.localToGlobal(Offset.zero, ancestor: viewport);
    final start = horizontal ? origin.dx : origin.dy;
    final extent = horizontal ? box.size.width : box.size.height;
    final viewportExtent = horizontal ? viewport.size.width : viewport.size.height;
    // Trigger when the element is comfortably inside the leading 92%.
    return start < viewportExtent * 0.92 && start + extent > 0;
  }

  void _trigger() {
    _position?.removeListener(_onScroll);
    _position = null;
    if (!_waiting) return;
    _waiting = false;
    if (!Scrollable.recommendDeferredLoadingForContext(context)) {
      _play();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_waiting) {
      // Keep layout, hide paint until it's time.
      return Opacity(opacity: 0, child: widget.child);
    }
    final progress = _progress;
    if (progress == null) return widget.child;
    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) {
        final t = progress.value;
        Widget result = Transform.translate(
          offset: _from * (1 - t),
          child: child,
        );
        if (widget.fade) {
          result = Opacity(opacity: t.clamp(0.0, 1.0), child: result);
        }
        return result;
      },
    );
  }
}

/// Hands out consistent delays **and** varied directions so a screen's
/// content enters as one choreographed sequence, with no two neighbours
/// entering from the same side.
///
/// ```dart
/// final seq = RevealSequence();
/// seq.wrap(Text('Title'))                                  // next direction
/// seq.wrap(Text('Sub'), direction: RevealDirection.top)    // explicit
/// ```
class RevealSequence {
  RevealSequence({
    this.start = Duration.zero,
    this.step = const Duration(milliseconds: 60),
    this.maxSteps = 10,
    this.pattern = defaultPattern,
    this.onVisible = true,
  });

  /// A balanced tour of edges: never repeats an axis twice in a row.
  static const List<RevealDirection> defaultPattern = [
    RevealDirection.start,
    RevealDirection.bottom,
    RevealDirection.end,
    RevealDirection.top,
    RevealDirection.bottomStart,
    RevealDirection.topEnd,
    RevealDirection.bottomEnd,
    RevealDirection.topStart,
  ];

  final Duration start;
  final Duration step;

  /// Delay stops growing after this many steps so late items never wait.
  final int maxSteps;
  final List<RevealDirection> pattern;

  /// Default for [wrap]: elements below the fold wait until visible.
  final bool onVisible;

  int _index = 0;

  Duration at(int index) =>
      start + step * (index > maxSteps ? maxSteps : index);

  Duration next() => at(_index++);

  RevealDirection directionAt(int index) => pattern[index % pattern.length];

  /// Wraps [child] with the next delay and (unless given) next direction.
  Widget wrap(
    Widget child, {
    RevealDirection? direction,
    double? distance,
    bool fade = true,
    Duration duration = AppMotion.slow,
    Curve curve = AppMotion.emphasized,
    bool? onVisible,
    Key? key,
  }) {
    final i = _index++;
    final dir = direction ?? directionAt(i);
    final vertical = dir == RevealDirection.top || dir == RevealDirection.bottom;
    return DirectionalTextReveal(
      key: key,
      direction: dir,
      delay: at(i),
      duration: duration,
      curve: curve,
      fade: fade,
      distance: distance ?? (vertical ? 16 : 24),
      onVisible: onVisible ?? this.onVisible,
      child: child,
    );
  }
}

extension DirectionalRevealX on Widget {
  /// Shorthand for [DirectionalTextReveal].
  Widget slideIn(
    RevealDirection direction, {
    Duration delay = Duration.zero,
    Duration duration = AppMotion.slow,
    Curve curve = AppMotion.emphasized,
    bool fade = true,
    double distance = 24,
    bool onVisible = false,
    Key? key,
  }) => DirectionalTextReveal(
    key: key,
    direction: direction,
    delay: delay,
    duration: duration,
    curve: curve,
    fade: fade,
    distance: distance,
    onVisible: onVisible,
    child: this,
  );

  /// List/grid item entrance whose direction follows its position:
  /// list rows alternate start/end; grid cells go by [column] of
  /// [columns] (left edge from start, right edge from end, middle from
  /// the bottom). Delay is capped like [AppMotion.stagger].
  Widget slideInAt(
    int index, {
    int columns = 1,
    double distance = 22,
    bool fade = true,
  }) {
    final RevealDirection dir;
    if (columns <= 1) {
      dir = index.isEven ? RevealDirection.start : RevealDirection.end;
    } else {
      final col = index % columns;
      dir = col == 0
          ? RevealDirection.start
          : col == columns - 1
          ? RevealDirection.end
          : RevealDirection.bottom;
    }
    return DirectionalTextReveal(
      direction: dir,
      delay: AppMotion.stagger(columns <= 1 ? index : index ~/ columns),
      duration: AppMotion.normal,
      distance: distance,
      fade: fade,
      child: this,
    );
  }
}
