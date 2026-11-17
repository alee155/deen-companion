import 'package:deen_companion/core/motion/motion.dart';
import 'package:deen_companion/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  FloatingNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  FloatingNavItem(
    icon: Icons.favorite_border_rounded,
    activeIcon: Icons.favorite_rounded,
    label: 'Favorites',
  ),
  FloatingNavItem(
    icon: Icons.groups_outlined,
    activeIcon: Icons.groups_rounded,
    label: 'Groups',
  ),
  FloatingNavItem(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

Widget _bar({
  required int current,
  required ValueChanged<int> onTap,
  required VoidCallback onCenter,
}) => ScreenUtilInit(
  designSize: const Size(375, 812),
  builder: (_, _) => MaterialApp(
    home: MotionScope(
      level: MotionLevel.reduced,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F1E6),
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FloatingNavBar(
            currentIndex: current,
            onTap: onTap,
            items: _items,
            center: FloatingNavCenter(
              icon: Icons.photo_camera_outlined,
              label: 'Send a snap',
              onTap: onCenter,
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('tabs report their own index and the camera is separate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final taps = <int>[];
    var camera = 0;
    await tester.pumpWidget(
      _bar(current: 0, onTap: taps.add, onCenter: () => camera++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Favorites'));
    await tester.tap(find.bySemanticsLabel('Groups'));
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.tap(find.bySemanticsLabel('Send a snap'));
    expect(taps, [1, 2, 3]);
    expect(camera, 1);
    // Settings is no longer in the bar.
    expect(find.bySemanticsLabel('Settings'), findsNothing);
  });
}
