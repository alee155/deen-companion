import 'package:flutter/widgets.dart';

import 'motion_scope.dart';
import 'motion_tokens.dart';

/// Cross-fades (with a small rise) when [text] changes; otherwise a plain
/// [Text]. Use for labels/subtitles that change with state.
class AnimatedText extends StatelessWidget {
  const AnimatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return ContentSwitcher(
      alignment: alignment,
      duration: AppMotion.fast,
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

/// Fade + slight rise swap for swapping content in place (tabs, categories,
/// state changes). Give the child a distinct `key` for each state.
class ContentSwitcher extends StatelessWidget {
  const ContentSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.normal,
    this.rise = 0.04,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final double rise;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return AnimatedSwitcher(
      duration: motion.duration(duration),
      reverseDuration: motion.duration(duration),
      switchInCurve: AppMotion.entrance,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final offset = motion.distance(rise);
        return FadeTransition(
          opacity: animation,
          child: offset == 0
              ? child
              : SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0, offset),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
        );
      },
      child: child,
    );
  }
}

/// Scale + fade swap for toggled icons (favourite heart, play/pause,
/// check states). Give each state's icon a distinct `key`.
class IconSwap extends StatelessWidget {
  const IconSwap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return AnimatedSwitcher(
      duration: motion.duration(AppMotion.fast),
      switchInCurve: AppMotion.pop,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: child,
    );
  }
}

/// Number that rolls to its new value. Animates from the previous value on
/// change (and from zero on first build when [fromZero] is set).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.format,
    this.fromZero = false,
    this.duration = AppMotion.value,
  });

  final num value;
  final TextStyle? style;
  final String Function(int value)? format;
  final bool fromZero;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: fromZero && !motion.reduced ? 0 : null,
        end: value.toDouble(),
      ),
      duration: motion.duration(duration),
      curve: AppMotion.entrance,
      builder: (context, v, _) {
        final n = v.round();
        return Text(format?.call(n) ?? '$n', style: style);
      },
    );
  }
}

/// Horizontal progress bar whose fill eases to a new [value] (0..1).
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.height = 6,
    this.duration = AppMotion.value,
    this.fromZero = true,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration duration;
  final bool fromZero;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final radius = BorderRadius.circular(height);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: fromZero && !motion.reduced ? 0 : null,
        end: value.clamp(0.0, 1.0),
      ),
      duration: motion.duration(duration),
      curve: AppMotion.entrance,
      builder: (context, v, _) => ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: backgroundColor)),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: v,
                  child: ColoredBox(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expand/collapse with size + fade. The child stays mounted only while
/// visible so collapsed content costs nothing.
class ExpandSection extends StatelessWidget {
  const ExpandSection({
    super.key,
    required this.expanded,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final bool expanded;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final d = context.motion.duration(AppMotion.normal);
    return AnimatedSize(
      duration: d,
      curve: AppMotion.emphasized,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: AppMotion.entrance,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: [...previous, ?current],
        ),
        child: expanded
            ? KeyedSubtree(key: const ValueKey('open'), child: child)
            : const SizedBox(key: ValueKey('closed'), width: double.infinity),
      ),
    );
  }
}

/// Brief scale "bump" whenever [value] changes — for streaks, tasbih
/// counters, badges. Does nothing on first build.
class BumpOnChange extends StatefulWidget {
  const BumpOnChange({
    super.key,
    required this.value,
    required this.child,
    this.peak = 1.12,
  });

  final Object? value;
  final Widget child;
  final double peak;

  @override
  State<BumpOnChange> createState() => _BumpOnChangeState();
}

class _BumpOnChangeState extends State<BumpOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: widget.peak).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: widget.peak, end: 1.0).chain(
        CurveTween(curve: Curves.easeOutBack),
      ),
      weight: 65,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(BumpOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !context.motion.reduced) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
