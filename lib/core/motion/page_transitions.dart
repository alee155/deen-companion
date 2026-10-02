import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion_tokens.dart';

/// Which motion a route uses.
enum AppTransitionKind {
  /// Default push: fade + small horizontal shift; the page underneath
  /// drifts back slightly.
  sharedAxis,

  /// Content rising from the bottom (full-screen player, modal flows).
  slideUp,

  /// Cross-fade with a hint of scale (splash → welcome → auth).
  fadeThrough,
}

/// Builds the actual transition; shared by the theme (for every default
/// route) and [AppTransitionPage] (for routes that pick a specific kind).
Widget buildAppTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  AppTransitionKind kind = AppTransitionKind.sharedAxis,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return _AppTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    kind: kind,
    child: child,
  );
}

class _AppTransition extends StatefulWidget {
  const _AppTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.kind,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final AppTransitionKind kind;
  final Widget child;

  @override
  State<_AppTransition> createState() => _AppTransitionState();
}

class _AppTransitionState extends State<_AppTransition> {
  late CurvedAnimation _in;
  late CurvedAnimation _out;

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    _in = CurvedAnimation(
      parent: widget.animation,
      curve: AppMotion.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
    _out = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: AppMotion.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(_AppTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation ||
        old.secondaryAnimation != widget.secondaryAnimation) {
      _in.dispose();
      _out.dispose();
      _build();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final fade = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0, 0.65, curve: Curves.easeOut),
      reverseCurve: const Interval(0.35, 1, curve: Curves.easeIn),
    );

    switch (widget.kind) {
      case AppTransitionKind.slideUp:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(_in),
          child: FadeTransition(opacity: fade, child: widget.child),
        );
      case AppTransitionKind.fadeThrough:
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(_in),
            child: widget.child,
          ),
        );
      case AppTransitionKind.sharedAxis:
        // Underlying page drifts slightly opposite to the incoming one. A
        // pure translate (no opacity layer) keeps this cheap.
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: Offset(-0.06 * dir, 0),
          ).animate(_out),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.08 * dir, 0),
              end: Offset.zero,
            ).animate(_in),
            child: FadeTransition(opacity: fade, child: widget.child),
          ),
        );
    }
  }
}

/// PageTransitionsBuilder for the theme — every route that doesn't choose
/// its own kind gets [AppTransitionKind.sharedAxis].
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => buildAppTransition(context, animation, secondaryAnimation, child);
}

/// Theme entry: custom motion on Android and others; iOS keeps the native
/// Cupertino push (with interactive edge-swipe back).
const PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

/// go_router page with an explicit transition kind. Durations collapse to
/// zero under reduced motion.
class AppTransitionPage<T> extends CustomTransitionPage<T> {
  AppTransitionPage({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    AppTransitionKind kind = AppTransitionKind.sharedAxis,
  }) : super(
         key: state.pageKey,
         name: state.name ?? state.path,
         arguments: <String, String>{...state.pathParameters},
         child: child,
         transitionDuration: MediaQuery.disableAnimationsOf(context)
             ? Duration.zero
             : AppMotion.page,
         reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
             ? Duration.zero
             : AppMotion.pageReverse,
         transitionsBuilder: (context, animation, secondary, child) =>
             buildAppTransition(context, animation, secondary, child, kind: kind),
       );
}
