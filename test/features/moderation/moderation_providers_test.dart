import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_reason.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_target.dart';
import 'package:deen_companion/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_storage_service.dart';
import '../prayer_logs/presentation/_prayer_log_test_support.dart';
import '_moderation_support.dart';

const _target = ReportUserTarget(userId: 'u1', userName: 'Sara');

void main() {
  late FakeModeration repo;

  ProviderContainer make() {
    repo = FakeModeration([blocked('old', name: 'Old')]);
    final c = ProviderContainer(
      overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('BlockedUsersNotifier', () {
    test('loads the saved list', () async {
      final c = make();
      final list = await c.read(blockedUsersProvider.future);
      expect(list.map((b) => b.userId), ['old']);
    });

    test('block adds the person at the top', () async {
      final c = make();
      await c.read(blockedUsersProvider.future);
      final r = await c
          .read(blockedUsersProvider.notifier)
          .block(blocked('new', name: 'New'));
      expect(r.when(success: (_) => true, failure: (_) => false), isTrue);
      expect(c.read(blockedUsersProvider).value!.map((b) => b.userId), [
        'new',
        'old',
      ]);
    });

    test('blocking someone already blocked does not duplicate them', () async {
      final c = make();
      await c.read(blockedUsersProvider.future);
      await c.read(blockedUsersProvider.notifier).block(blocked('old'));
      expect(c.read(blockedUsersProvider).value, hasLength(1));
    });

    test('unblock removes the person', () async {
      final c = make();
      await c.read(blockedUsersProvider.future);
      await c.read(blockedUsersProvider.notifier).unblock('old');
      expect(c.read(blockedUsersProvider).value, isEmpty);
      expect(repo.unblockCalls, 1);
    });

    test('a failed block leaves the list alone and says why', () async {
      final c = make();
      await c.read(blockedUsersProvider.future);
      repo.failure = const CacheFailure(
        'Couldn’t block this person. Try again.',
      );
      final r = await c
          .read(blockedUsersProvider.notifier)
          .block(blocked('new'));
      expect(
        r.when(success: (_) => '', failure: (f) => f.message),
        'Couldn’t block this person. Try again.',
      );
      expect(c.read(blockedUsersProvider).value!.map((b) => b.userId), ['old']);
    });

    test('a failed unblock leaves the person blocked', () async {
      final c = make();
      await c.read(blockedUsersProvider.future);
      repo.failure = const CacheFailure('nope');
      await c.read(blockedUsersProvider.notifier).unblock('old');
      expect(c.read(blockedUsersProvider).value, hasLength(1));
    });

    test('a list that cannot be read is an error to show', () async {
      final c = make();
      repo.failure = const CacheFailure('Couldn’t load your blocked users.');
      await expectLater(
        c.read(blockedUsersProvider.future),
        throwsA(isA<CacheFailure>()),
      );
    });
  });

  group('blockedUserIdsProvider', () {
    test('is empty until the list loads, so nothing is hidden early', () {
      final c = make();
      expect(c.read(blockedUserIdsProvider), isEmpty);
    });

    test('holds the ids once loaded, and follows changes', () async {
      final c = make();
      await c.read(blockedUsersProvider.future);
      expect(c.read(blockedUserIdsProvider), {'old'});

      await c.read(blockedUsersProvider.notifier).block(blocked('b'));
      expect(c.read(blockedUserIdsProvider), {'old', 'b'});

      await c.read(blockedUsersProvider.notifier).unblock('old');
      expect(c.read(blockedUserIdsProvider), {'b'});
    });
  });

  group('ReportController', () {
    test('submits the reason and the target', () async {
      final c = make();
      final ok = await c
          .read(reportControllerProvider.notifier)
          .submit(target: _target, reason: ReportReason.harassment);
      expect(ok, isTrue);
      expect(repo.reports.single.target, _target);
      expect(repo.reports.single.reason, ReportReason.harassment);
    });

    test('trims the note, and an empty note is sent as none', () async {
      final c = make();
      final n = c.read(reportControllerProvider.notifier);
      await n.submit(
        target: _target,
        reason: ReportReason.spam,
        details: '  hi  ',
      );
      await n.submit(
        target: _target,
        reason: ReportReason.spam,
        details: '   ',
      );
      await n.submit(target: _target, reason: ReportReason.spam);
      expect(repo.reports.map((r) => r.details), ['hi', null, null]);
    });

    test('shows sending while it works', () async {
      final c = make();
      repo.hold = true;
      final sub = c.listen(reportControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final future = c
          .read(reportControllerProvider.notifier)
          .submit(target: _target, reason: ReportReason.spam);
      expect(c.read(reportControllerProvider).isSubmitting, isTrue);
      await future;
      expect(c.read(reportControllerProvider).isSubmitting, isFalse);
    });

    test('a failure comes back as a message and a false result', () async {
      final c = make();
      repo.failure = const ServerFailure('Server is busy.');
      final sub = c.listen(reportControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final ok = await c
          .read(reportControllerProvider.notifier)
          .submit(target: _target, reason: ReportReason.spam);
      expect(ok, isFalse);
      expect(c.read(reportControllerProvider).errorMessage, 'Server is busy.');
      expect(c.read(reportControllerProvider).isSubmitting, isFalse);
    });

    test('a second tap while sending does not send twice', () async {
      final c = make();
      repo.hold = true;
      final sub = c.listen(reportControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final n = c.read(reportControllerProvider.notifier);
      final first = n.submit(target: _target, reason: ReportReason.spam);
      final second = await n.submit(target: _target, reason: ReportReason.spam);
      await first;
      expect(second, isFalse);
      expect(repo.reports, hasLength(1));
    });

    test('retrying after a failure clears the old error', () async {
      final c = make();
      final sub = c.listen(reportControllerProvider, (_, _) {});
      addTearDown(sub.close);
      repo.failure = const ServerFailure('down');
      final n = c.read(reportControllerProvider.notifier);
      await n.submit(target: _target, reason: ReportReason.spam);
      repo.failure = null;
      expect(
        await n.submit(target: _target, reason: ReportReason.spam),
        isTrue,
      );
      expect(c.read(reportControllerProvider).errorMessage, isNull);
    });
  });

  group('moderationRepositoryProvider', () {
    test(
      'uses the signed-in account, so blocks are kept per account',
      () async {
        final storage = InMemoryStorageService();
        final c = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            authSessionProvider.overrideWith(SignedIn.new),
          ],
        );
        addTearDown(c.dispose);

        await c.read(blockedUsersProvider.future);
        await c.read(blockedUsersProvider.notifier).block(blocked('a'));

        // Saved under this account's own key.
        expect(
          storage.boxes.values.expand((b) => b.keys),
          contains('blocked_users:me'),
        );
        expect(c.read(blockedUserIdsProvider), {'a'});
      },
    );
  });
}
