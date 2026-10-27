import 'package:deen_companion/core/utils/share_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  Map<Object?, Object?>? sent;

  setUp(() {
    sent = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'share') {
            sent = call.arguments as Map<Object?, Object?>;
          }
          return '';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('anchors the share popover to the widget it was called from', (
    tester,
  ) async {
    late BuildContext inner;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: SizedBox(
              width: 120,
              height: 50,
              child: Builder(
                builder: (context) {
                  inner = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );

    await shareText(inner, 'hello', subject: 'subj');

    expect(sent!['text'], 'hello');
    expect(sent!['subject'], 'subj');
    expect(sent!['originX'], 40.0);
    expect(sent!['originY'], 40.0);
    expect(sent!['originWidth'], 120.0);
    expect(sent!['originHeight'], 50.0);
  });

  testWidgets('always sends an anchor, falling back to the screen centre', (
    tester,
  ) async {
    late BuildContext outer;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          outer = context;
          return const SizedBox();
        },
      ),
    );
    // A context above any MediaQuery cannot be measured: use a bare one.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Builder(
          builder: (context) {
            outer = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await shareText(outer, 'hello');

    expect(sent!['originX'], isNotNull);
    expect(sent!['originWidth'], isNotNull);
  });
}
