import 'dart:convert';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/moderation/data/local_moderation_repository.dart';
import 'package:deen_companion/features/moderation/domain/entities/blocked_user.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_reason.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_target.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_storage_service.dart';
import '_moderation_support.dart';

/// Storage that cannot be written, for the failure paths.
class _BrokenStorage extends InMemoryStorageService {
  @override
  Future<void> put(String boxName, String key, dynamic value) =>
      throw Exception('disk full');
}

Future<List<BlockedUser>> _list(LocalModerationRepository r) async =>
    (await r.getBlockedUsers()).when(
      success: (d) => d,
      failure: (f) => throw f,
    );

void main() {
  group('BlockedUser', () {
    test('round-trips through JSON', () {
      final u = BlockedUser(
        userId: 'u1',
        name: 'Sara Ahmed',
        avatarUrl: 'https://x.test/a.png',
        blockedAt: DateTime.utc(2026, 10, 28, 9, 30),
      );
      expect(BlockedUser.fromJson(u.toJson()), u);
    });

    test('unusable records are skipped, not fatal', () {
      expect(BlockedUser.fromJson(null), isNull);
      expect(BlockedUser.fromJson('text'), isNull);
      expect(BlockedUser.fromJson({'name': 'no id'}), isNull);
      expect(BlockedUser.fromJson({'userId': ''}), isNull);
    });

    test('a record with only an id still loads', () {
      final u = BlockedUser.fromJson({'userId': 'u1'})!;
      expect(u.userId, 'u1');
      expect(u.name, '');
      expect(u.avatarUrl, isNull);
    });

    test('initials come from the first two words', () {
      expect(blocked('a', name: 'Sara Ahmed Khan').initials, 'SA');
      expect(blocked('a', name: 'omar').initials, 'O');
      expect(blocked('a', name: '').initials, '?');
    });
  });

  test('every reason has a stable name for the API', () {
    expect(ReportReason.values.map((r) => r.apiValue), [
      'inappropriate',
      'harassment',
      'spam',
      'impersonation',
      'other',
    ]);
  });

  group('LocalModerationRepository', () {
    late InMemoryStorageService storage;
    LocalModerationRepository repo({String? owner = 'me'}) =>
        LocalModerationRepository(storage: storage, ownerId: owner);

    setUp(() => storage = InMemoryStorageService());

    test('starts with nobody blocked', () async {
      expect(await _list(repo()), isEmpty);
    });

    test('a block is kept, newest first, and survives a restart', () async {
      await repo().blockUser(blocked('a', name: 'Ali'));
      await repo().blockUser(blocked('b', name: 'Bilal'));

      // A fresh repository over the same storage, as after relaunching.
      final again = await _list(repo());
      expect(again.map((b) => b.userId), ['b', 'a']);
      expect(again.map((b) => b.name), ['Bilal', 'Ali']);
    });

    test('blocking the same person twice keeps one entry', () async {
      await repo().blockUser(blocked('a', name: 'Ali'));
      await repo().blockUser(blocked('a', name: 'Ali Updated'));
      final list = await _list(repo());
      expect(list, hasLength(1));
      expect(list.single.name, 'Ali Updated');
    });

    test('unblocking removes only that person', () async {
      await repo().blockUser(blocked('a'));
      await repo().blockUser(blocked('b'));
      await repo().unblockUser('a');
      expect((await _list(repo())).map((b) => b.userId), ['b']);
    });

    test('unblocking someone who is not blocked is harmless', () async {
      await repo().blockUser(blocked('a'));
      expect(await repo().unblockUser('zzz'), isA<Success<void>>());
      expect(await _list(repo()), hasLength(1));
    });

    test('each account has its own list', () async {
      await repo(owner: 'me').blockUser(blocked('a'));
      expect(await _list(repo(owner: 'someone-else')), isEmpty);
      expect(await _list(repo(owner: null)), isEmpty);
      expect(await _list(repo(owner: 'me')), hasLength(1));
    });

    test('damaged saved data reads as empty instead of crashing', () async {
      final key = '${AppConstants.blockedUsersKey}:me';
      await storage.put(AppConstants.settingsBoxName, key, 'not json {{');
      expect((await repo().getBlockedUsers()), isA<Error<List<BlockedUser>>>());

      await storage.put(AppConstants.settingsBoxName, key, '{"a":1}');
      expect(await _list(repo()), isEmpty);

      await storage.put(
        AppConstants.settingsBoxName,
        key,
        jsonEncode([
          {'userId': 'ok', 'name': 'Fine'},
          {'no': 'id'},
          42,
        ]),
      );
      expect((await _list(repo())).map((b) => b.userId), ['ok']);
    });

    test('a storage failure is reported, not thrown', () async {
      final broken = LocalModerationRepository(
        storage: _BrokenStorage(),
        ownerId: 'me',
      );
      final r = await broken.blockUser(blocked('a'));
      expect(r, isA<Error<void>>());
      expect((r as Error<void>).failure, isA<CacheFailure>());
      expect(await broken.unblockUser('a'), isA<Error<void>>());
    });

    test(
      'a report is accepted but stores nothing (it is not sent yet)',
      () async {
        final r = await repo().report(
          target: const ReportUserTarget(userId: 'u', userName: 'U'),
          reason: ReportReason.spam,
          details: 'private note',
        );
        expect(r, isA<Success<void>>());
        expect(storage.boxes, isEmpty, reason: 'nothing was persisted');
      },
    );
  });

  group('ReportTarget', () {
    test('a snap target names its snap and its sender', () {
      const t = ReportSnapTarget(snapId: 's1', userId: 'u1', userName: 'Sara');
      expect(t.snapId, 's1');
      expect(t.userId, 'u1');
      expect(
        t,
        const ReportSnapTarget(snapId: 's1', userId: 'u1', userName: 'Sara'),
      );
      expect(
        t,
        isNot(
          const ReportSnapTarget(snapId: 's2', userId: 'u1', userName: 'Sara'),
        ),
      );
    });

    test('a user target is not equal to a snap target', () {
      expect(
        const ReportUserTarget(userId: 'u1', userName: 'Sara'),
        isNot(
          const ReportSnapTarget(snapId: 's', userId: 'u1', userName: 'Sara'),
        ),
      );
    });
  });

  test('LocalStorageService is what the repository needs (compile check)', () {
    // Guards the constructor's contract if the storage interface changes.
    LocalStorageService s = InMemoryStorageService();
    expect(
      LocalModerationRepository(storage: s, ownerId: null).ownerId,
      isNull,
    );
  });
}
