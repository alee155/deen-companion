import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/core/utils/flow_log.dart';
import 'package:deen_companion/features/snaps/data/mock/mock_snap_repository.dart';
import 'package:deen_companion/features/snaps/domain/entities/snap_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> lines;

  setUp(() {
    lines = [];
    FlowLog.enabledOverride = true;
    FlowLog.sink = lines.add;
  });

  tearDown(() {
    FlowLog.enabledOverride = null;
    FlowLog.sink = null;
  });

  test('the placeholder send says plainly that no API is called', () async {
    final result = await const MockSnapRepository().sendSnap(
      const SnapDraft(
        groupId: 'g1',
        imagePath: '/tmp/private-path/photo.jpg',
        viewSeconds: 5,
        caption: 'a private caption',
        recipientIds: ['u2', 'u3'],
      ),
    );
    expect(result, isA<Success>());

    final out = lines.join('\n');
    expect(out, contains('[SEND SNAP] SIMULATED SEND - NO API IS CALLED'));
    expect(out, contains('SIMULATED RESULT: success'));
    // What would have been sent is described, not dumped.
    expect(out, contains('recipients: 2'));
    expect(out, contains('hasCaption: true'));
    expect(out, isNot(contains('a private caption')));
    expect(out, isNot(contains('private-path')));
    for (final l in lines) {
      expect(l, startsWith('********** '));
      expect(l, endsWith(' **********'));
    }
  });
}
