/// App-wide motion system. Import this one file.
///
///  * [AppMotion] — durations, curves, stagger, distances, overlay styles
///  * [MotionScope] / `context.motion` — reduced-motion + intensity
///  * [Reveal] and `.appear()/.appearStaggered()/.popIn()/.celebrate()`
///  * [Pressable] (tappable) / [PressScale] (feedback only, wraps InkWell)
///  * [AnimatedText], [ContentSwitcher], [IconSwap], [AnimatedCount],
///    [AnimatedProgressBar], [ExpandSection], [BumpOnChange]
///  * [AppPageTransitionsBuilder], [AppTransitionPage],
///    [AnimatedBranchContainer]
///  * [AppHaptics]
///
/// Sheets/dialogs: pass `sheetAnimationStyle: AppMotion.sheetStyle` to
/// `showModalBottomSheet` and `animationStyle: AppMotion.dialogStyle` to
/// `showDialog`.
library;

export 'animated_widgets.dart';
export 'branch_container.dart';
export 'directional_reveal.dart';
export 'haptics.dart';
export 'motion_scope.dart';
export 'motion_tokens.dart';
export 'page_transitions.dart';
export 'pressable.dart';
export 'reveal.dart';
