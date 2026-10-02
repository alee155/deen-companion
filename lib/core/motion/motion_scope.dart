import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion_tokens.dart';

/// User/app-level motion intensity. The OS reduced-motion setting is applied
/// on top of this by [MotionScope], so this only ever needs to express taste.
final motionLevelProvider = StateProvider<MotionLevel>(
  (ref) => MotionLevel.standard,
);

/// Resolved motion settings for a subtree.
@immutable
class MotionSpec {
  const MotionSpec({required this.level});

  final MotionLevel level;

  bool get reduced => level == MotionLevel.reduced;

  /// Scales an entrance travel distance for the current [level].
  double distance(double base) => base * level.distanceScale;

  /// Returns [d], or zero when motion is reduced — feed to any duration so
  /// state changes become immediate instead of animated.
  Duration duration(Duration d) => reduced ? Duration.zero : d;
}

/// Installs the resolved [MotionSpec] for the app. Place once, below
/// `MaterialApp` (needs `MediaQuery`), e.g. in `MaterialApp.builder`.
class MotionScope extends StatelessWidget {
  const MotionScope({super.key, required this.level, required this.child});

  final MotionLevel level;
  final Widget child;

  static const MotionSpec _standard = MotionSpec(level: MotionLevel.standard);
  static const MotionSpec _reduced = MotionSpec(level: MotionLevel.reduced);

  /// Resolves motion settings for [context]. Works without a scope (falls
  /// back to the OS setting), so widgets are safe in tests and previews.
  static MotionSpec of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_MotionInherited>();
    if (inherited != null) return inherited.spec;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? _reduced
        : _standard;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.disableAnimationsOf(context);
    final effective = disabled ? MotionLevel.reduced : level;
    return _MotionInherited(spec: MotionSpec(level: effective), child: child);
  }
}

class _MotionInherited extends InheritedWidget {
  const _MotionInherited({required this.spec, required super.child});

  final MotionSpec spec;

  @override
  bool updateShouldNotify(_MotionInherited old) => old.spec.level != spec.level;
}

extension MotionContext on BuildContext {
  MotionSpec get motion => MotionScope.of(this);
}
