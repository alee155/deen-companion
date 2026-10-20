import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/streaks/domain/entities/my_streaks.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_streaks_support.dart';

class _SignedIn extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'u1', email: 'a@b.c', name: 'Alee');
  void switchTo(String id) =>
      state = AuthSession(userId: id, email: '$id@b.c', name: id);
}

class _Guest extends AuthSessionNotifier {
  @override
  AuthSession build() => const AuthSession();
}

void main() {
  late FakeStreaksRepo repo;
  setUp(() => repo = FakeStreaksRepo());

  ProviderContainer make({bool signedIn = true}) {
    final c = ProviderContainer(
      overrides: [
        streaksRepositoryProvider.overrideWithValue(repo),
        authSessionProvider.overrideWith(signedIn ? _SignedIn.new : _Guest.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('reads', () {
    test(
      'the board, the rule and my streaks come from the repository',
      () async {
        repo.mine = Success(sampleMine());
        final c = make();
        expect(
          (await c.read(groupStreakBoardProvider('g1').future)).entries,
          hasLength(2),
        );
        expect((await c.read(streakRuleProvider('g1').future)).minPrayers, 1);
        expect((await c.read(myStreaksProvider.future)).currentBest, 7);
      },
    );

    test('a failure surfaces as the Failure', () async {
      repo.board = offline;
      repo.mine = offline;
      final c = make();
      await expectLater(
        c.read(groupStreakBoardProvider('g1').future),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        c.read(myStreaksProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a guest has no streaks and the server is never asked', () async {
      final c = make(signedIn: false);
      expect(await c.read(myStreaksProvider.future), MyStreaks.empty);
      expect(repo.mineCalls, 0);
    });
  });

  group('refreshing', () {
    test('invalidateStreaks makes the next read ask again', () async {
      final c = make();
      final sub = c.listen(groupStreakBoardProvider('g1'), (_, _) {});
      final sub2 = c.listen(myStreaksProvider, (_, _) {});
      await c.read(groupStreakBoardProvider('g1').future);
      await c.read(myStreaksProvider.future);
      expect((repo.boardCalls, repo.mineCalls), (1, 1));

      c.read(_invalidator)();
      await c.read(groupStreakBoardProvider('g1').future);
      await c.read(myStreaksProvider.future);
      expect((repo.boardCalls, repo.mineCalls), (2, 2));
      sub.close();
      sub2.close();
    });

    test('another account signing in drops the kept data', () async {
      final c = make();
      final sub = c.listen(groupStreakBoardProvider('g1'), (_, _) {});
      await c.read(groupStreakBoardProvider('g1').future);
      sub.close();
      await Future<void>.delayed(Duration.zero);

      (c.read(authSessionProvider.notifier) as _SignedIn).switchTo('u2');
      await Future<void>.delayed(Duration.zero);
      await c.read(groupStreakBoardProvider('g1').future);
      expect(repo.boardCalls, 2, reason: 'u2 must not see u1\'s board');
    });
  });

  group('StreakRuleController', () {
    test(
      'saving asks the server and refreshes what depends on the rule',
      () async {
        final c = make();
        final subs = [
          c.listen(streakRuleProvider('g1'), (_, _) {}),
          c.listen(groupStreakBoardProvider('g1'), (_, _) {}),
          c.listen(myStreaksProvider, (_, _) {}),
        ];
        await c.read(streakRuleProvider('g1').future);
        await c.read(groupStreakBoardProvider('g1').future);
        await c.read(myStreaksProvider.future);

        final ok = await c
            .read(streakRuleControllerProvider.notifier)
            .save('g1', 3);
        expect(ok, isTrue);
        expect(repo.setRuleCalls, [3]);
        expect((await c.read(streakRuleProvider('g1').future)).minPrayers, 3);
        await c.read(groupStreakBoardProvider('g1').future);
        await c.read(myStreaksProvider.future);
        expect(repo.boardCalls, 2);
        expect(repo.mineCalls, 2);
        expect(c.read(streakRuleControllerProvider).errorMessage, isNull);
        for (final s in subs) {
          s.close();
        }
      },
    );

    test('a rejection is shown and nothing is refreshed', () async {
      repo.rule = const Error(ServerFailure('Only the admin can do this'));
      final c = make();
      final ok = await c
          .read(streakRuleControllerProvider.notifier)
          .save('g1', 3);
      expect(ok, isFalse);
      final s = c.read(streakRuleControllerProvider);
      expect(s.errorMessage, 'Only the admin can do this');
      expect(s.isSaving, isFalse);
    });

    test('a second save while one is running is ignored', () async {
      final c = make();
      final n = c.read(streakRuleControllerProvider.notifier);
      final first = n.save('g1', 2);
      final second = await n.save('g1', 4);
      expect(second, isFalse);
      await first;
      expect(repo.setRuleCalls, [2]);
    });
  });
}

/// Calls [invalidateStreaks] with a real [Ref].
final _invalidator = Provider<void Function()>(
  (ref) =>
      () => invalidateStreaks(ref),
);
