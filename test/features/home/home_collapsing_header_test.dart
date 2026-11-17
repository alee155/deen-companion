import 'package:deen_companion/features/home/presentation/widgets/home_slider_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Home's pinned header: open when the page opens, a slim bar while it
/// scrolls, with the page content moving under it.
void main() {
  const expanded = 340.0;
  const collapsed = 110.0;

  late ScrollController controller;
  final seen = <({double height, double collapse})>[];

  setUp(() {
    controller = ScrollController();
    seen.clear();
  });
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: HomeHeaderDelegate(
                  expandedHeight: expanded,
                  collapsedHeight: collapsed,
                  builder: (context, height, collapse) {
                    seen.add((height: height, collapse: collapse));
                    return Container(
                      key: const ValueKey('header'),
                      height: height,
                      color: Colors.black,
                    );
                  },
                ),
              ),
              SliverList.builder(
                itemCount: 60,
                itemBuilder: (_, i) => SizedBox(
                  height: 80,
                  child: Text('row $i', key: ValueKey('row $i')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double headerHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(const ValueKey('header'))).height;

  testWidgets('opens fully, with the content right below it', (tester) async {
    await pump(tester);
    expect(headerHeight(tester), expanded);
    expect(seen.last.collapse, 0);
    expect(tester.getTopLeft(find.byKey(const ValueKey('row 0'))).dy, expanded);
  });

  testWidgets('shrinks as the page scrolls, and reports how far', (
    tester,
  ) async {
    await pump(tester);
    // Halfway through the 230 it can shrink by.
    controller.jumpTo(115);
    await tester.pump();
    expect(headerHeight(tester), closeTo(225, 0.5));
    expect(seen.last.collapse, closeTo(0.5, 0.01));
  });

  testWidgets('stops at the slim bar and stays pinned to the top', (
    tester,
  ) async {
    await pump(tester);
    controller.jumpTo(900);
    await tester.pump();
    expect(headerHeight(tester), collapsed);
    expect(seen.last.collapse, 1);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('header'))).dy,
      0,
      reason: 'still at the top of the screen',
    );
  });

  testWidgets('the content scrolls under the pinned header', (tester) async {
    await pump(tester);
    controller.jumpTo(900);
    await tester.pump();
    // Row 8 begins 340 + 8 x 80 - 900 = 80 down: above the bottom edge of the
    // slim bar (110), so it is passing under it.
    final top = tester.getTopLeft(find.byKey(const ValueKey('row 8'))).dy;
    expect(top, closeTo(80, 0.5));
    expect(top, lessThan(collapsed));
  });

  testWidgets('opens again when scrolled back to the top', (tester) async {
    await pump(tester);
    controller.jumpTo(900);
    await tester.pump();
    controller.jumpTo(0);
    await tester.pump();
    expect(headerHeight(tester), expanded);
    expect(seen.last.collapse, 0);
  });
}
