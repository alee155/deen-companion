import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../motion/motion.dart';
import '../theme/app_colors.dart';

/// The dark pill the tabs sit on: the app's own dark surface, as the bar has
/// always used.
Color get _barColor => AppColors.heroSurface;

/// The active tab and the centre button: the app's accent (orange).
Color get _accent => AppColors.emeraldInk;

/// Tabs that are not selected.
const _inactive = Color(0xFFC9B3A0);

/// The ring around the centre button.
const _ring = Colors.white;

/// How far the centre button rises above the pill.
const double _lift = 9.5;

/// Dark floating pill with icon-only tabs and a round action button raised in
/// the middle. The tabs are split evenly around the button: the first half
/// left of it, the rest right of it.
///
/// [currentIndex] and [onTap] count the [items] only; the centre button is not
/// a tab and has its own [center] callback.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;
  final FloatingNavCenter center;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    final split = (items.length / 2).ceil();
    // One slot per tab plus one for the button, all the same width.
    final slots = items.length + 1;

    Widget tab(int index, int slot) => Expanded(
      child: _NavItem(
        data: items[index],
        isSelected: currentIndex == index,
        onTap: () => onTap(index),
      ).slideInAt(slot, columns: slots, distance: 16),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, _lift.h, 20.w, 24.h),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 66.h,
            decoration: BoxDecoration(
              color: _barColor,
              borderRadius: BorderRadius.circular(40.r),
              boxShadow: [
                BoxShadow(
                  color: _barColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < split; i++) tab(i, i),
                // The button's own slot.
                const Spacer(),
                for (var i = split; i < items.length; i++) tab(i, i + 1),
              ],
            ),
          ),
          Positioned(
            top: -_lift.h,
            child: _CenterButton(data: center).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 80),
              distance: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingNavItem {
  /// Shown when the tab is not selected (an outline).
  final IconData? icon;

  /// Shown when it is selected (filled).
  final IconData? activeIcon;

  /// For an icon the Material set doesn't have: drawn in [color] at [size].
  final Widget Function(Color color, double size)? iconBuilder;

  /// Read out by screen readers; the bar itself shows no text.
  final String label;

  const FloatingNavItem({
    required IconData this.icon,
    required IconData this.activeIcon,
    required this.label,
  }) : iconBuilder = null;

  const FloatingNavItem.custom({required this.iconBuilder, required this.label})
    : icon = null,
      activeIcon = null;
}

/// The round action button in the middle of the bar.
class FloatingNavCenter {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FloatingNavCenter({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _NavItem extends StatelessWidget {
  final FloatingNavItem data;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return Semantics(
      button: true,
      selected: isSelected,
      label: data.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: () {
          if (!isSelected) AppHaptics.selection();
          onTap();
        },
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: AnimatedSwitcher(
              duration: motion.duration(AppMotion.fast),
              child: KeyedSubtree(
                key: ValueKey(isSelected),
                child: data.iconBuilder != null
                    ? data.iconBuilder!(isSelected ? _accent : _inactive, 26.sp)
                    : Icon(
                        isSelected ? data.activeIcon : data.icon,
                        size: 26.sp,
                        color: isSelected ? _accent : _inactive,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final FloatingNavCenter data;
  const _CenterButton({required this.data});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: data.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: data.onTap,
        child: Container(
          width: 59.w,
          height: 59.w,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _ring),
          alignment: Alignment.center,
          child: Container(
            width: 51.w,
            height: 51.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _accent),
            alignment: Alignment.center,
            child: Icon(data.icon, size: 24.sp, color: _barColor),
          ),
        ),
      ),
    );
  }
}
