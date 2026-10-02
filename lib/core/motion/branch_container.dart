import 'package:flutter/widgets.dart';

import 'motion_scope.dart';
import 'motion_tokens.dart';

/// Bottom-tab body: keeps every branch alive (like `IndexedStack`, so scroll
/// position and state survive) but softly fades the newly selected tab in
/// instead of snapping. Pass to `StatefulShellRoute.navigatorContainerBuilder`.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: 1,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.35,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.entrance));
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.entrance));

  @override
  void didUpdateWidget(AnimatedBranchContainer old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && !context.motion.reduced) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: IndexedStack(
          index: widget.currentIndex,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              // Inactive tabs stop ticking (their own animations pause).
              TickerMode(
                enabled: i == widget.currentIndex,
                child: widget.children[i],
              ),
          ],
        ),
      ),
    );
  }
}
