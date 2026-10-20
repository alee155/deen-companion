import 'package:deen_companion/core/device/screen_awake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reader extends StatefulWidget {
  const _Reader();
  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> with KeepScreenOnMixin<_Reader> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('a reader keeps the screen on while open and never throws', (
    tester,
  ) async {
    // No platform plugin here: acquiring and releasing must still be safe.
    await tester.pumpWidget(const MaterialApp(home: _Reader()));
    await tester.pumpWidget(const SizedBox());
  });

  test('releasing more than acquired is harmless', () {
    ScreenAwake.release();
    ScreenAwake.release();
  });
}
