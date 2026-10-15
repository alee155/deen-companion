import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_log_composer.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../snaps/snap_fakes.dart';
import '_prayer_log_test_support.dart';

void main() {
  late FakeProcessor processor;
  late ScriptedLogsRepo repo;
  late ProviderContainer c;

  setUp(() {
    processor = FakeProcessor();
    repo = ScriptedLogsRepo();
    c = ProviderContainer(
      overrides: [
        snapImageProcessorProvider.overrideWithValue(processor),
        prayerLogsRepositoryProvider.overrideWithValue(repo),
        currentPrayerProvider.overrideWith(() => FixedCurrent(openState())),
      ],
    );
    addTearDown(c.dispose);
  });

  PrayerLogComposerController n() => c.read(prayerLogComposerProvider.notifier);
  PrayerLogComposerState s() => c.read(prayerLogComposerProvider);

  Future<void> toConfirm() async {
    await n().onCaptured('/tmp/a.jpg');
    await n().onCropped(tinyPng);
  }

  test('capture then crop reaches confirm with a compressed upload', () async {
    await n().onCaptured('/tmp/a.jpg');
    expect(s().step, PrayerLogStep.crop);
    expect(s().source, isNotNull);

    await n().onCropped(tinyPng);
    expect(s().step, PrayerLogStep.confirm);
    expect(s().prepared!.path, '/tmp/prepared.jpg');
    expect(s().canSubmit, isTrue);
  });

  test('cannot submit before the photo is prepared', () async {
    expect(await n().submit(), isFalse);
    expect(repo.logged, isEmpty);
  });

  test('a read failure stays on capture with the message', () async {
    processor.editFailure = const UnexpectedFailure('bad photo');
    await n().onCaptured('/tmp/a.jpg');
    expect(s().step, PrayerLogStep.capture);
    expect(s().errorMessage, 'bad photo');
  });

  test('a compress failure blocks submitting', () async {
    processor.compressFailure = const UnexpectedFailure('cannot compress');
    await toConfirm();
    expect(s().canSubmit, isFalse);
    expect(s().errorMessage, 'cannot compress');
  });

  test('submit uploads the prepared file and records the log', () async {
    repo.logResult = Success(logOf(PrayerName.asr));
    await toConfirm();
    expect(await n().submit(), isTrue);
    expect(repo.logged, ['/tmp/prepared.jpg']);
    expect(s().logged!.prayer, PrayerName.asr);
    expect(s().wasAlreadyLogged, isFalse);
  });

  test('already logged counts as done and keeps the existing log', () async {
    repo.logResult = Error(
      PrayerLogFailure(
        'dup',
        code: PrayerLogErrorCode.alreadyLogged,
        existingLog: logOf(PrayerName.asr, id: 'old'),
      ),
    );
    await toConfirm();
    expect(await n().submit(), isTrue);
    expect(s().wasAlreadyLogged, isTrue);
    expect(s().logged!.id, 'old');
  });

  test('no open window stays on confirm and names the next prayer', () async {
    repo.logResult = Error(
      PrayerLogFailure(
        'No active prayer window',
        code: PrayerLogErrorCode.noActiveWindow,
        nextPrayer: PrayerName.maghrib,
        nextStartsAt: DateTime.utc(2026, 10, 13, 12, 25),
      ),
    );
    await toConfirm();
    expect(await n().submit(), isFalse);
    expect(s().step, PrayerLogStep.confirm);
    expect(s().errorMessage, contains('Maghrib starts at'));
    expect(s().canSubmit, isTrue, reason: 'the user can retry or retake');
  });

  test('retake discards everything', () async {
    await toConfirm();
    n().retake();
    expect(s().step, PrayerLogStep.capture);
    expect(s().cropped, isNull);
    expect(s().prepared, isNull);
  });

  test('temp files are cleaned up when the flow closes', () async {
    await toConfirm();
    c.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(processor.cleaned, containsAll(['/tmp/a.jpg', '/tmp/prepared.jpg']));
  });
}
