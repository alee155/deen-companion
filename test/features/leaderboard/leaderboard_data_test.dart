import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/leaderboard/data/datasources/leaderboard_remote_datasource.dart';
import 'package:deen_companion/features/leaderboard/data/models/leaderboard_models.dart';
import 'package:deen_companion/features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import 'package:deen_companion/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(
  int rank,
  String id, {
  String role = 'member',
  int points = 10,
}) => {
  'rank': rank,
  'userId': id,
  'name': 'User $id',
  'role': role,
  'points': points,
  'prayersLogged': 4,
  'currentStreak': 2,
};

class _Remote implements LeaderboardRemoteDataSource {
  _Remote({this.rows, this.error});
  final List<LeaderboardEntry>? rows;
  final Object? error;
  String? asked;

  @override
  Future<List<LeaderboardEntry>> leaderboard(String groupId) async {
    asked = groupId;
    if (error != null) throw error!;
    return rows!;
  }
}

void main() {
  group('leaderboardFromJson', () {
    test('reads a bare array', () {
      final rows = leaderboardFromJson([
        _row(1, 'a', role: 'admin', points: 30),
        _row(2, 'b'),
      ]);
      expect(rows.map((e) => e.userId), ['a', 'b']);
      expect(rows.first.role, GroupRole.admin);
      expect(rows.first.points, 30);
      expect(rows.first.prayersLogged, 4);
      expect(rows.first.currentStreak, 2);
    });

    test('reads the {success, data} wrapper', () {
      final rows = leaderboardFromJson({
        'success': true,
        'data': [_row(1, 'a')],
      });
      expect(rows, hasLength(1));
    });

    test('orders by rank whatever order it arrives in', () {
      final rows = leaderboardFromJson([
        _row(3, 'c'),
        _row(1, 'a'),
        _row(2, 'b'),
      ]);
      expect(rows.map((e) => e.rank), [1, 2, 3]);
    });

    test('a row of the wrong shape is a TypeError, not a half board', () {
      expect(
        () => leaderboardFromJson([
          {'rank': 1},
        ]),
        throwsA(isA<TypeError>()),
      );
    });

    test('numbers sent as decimals are accepted', () {
      final rows = leaderboardFromJson([
        {..._row(1, 'a'), 'points': 12.0, 'rank': 1.0},
      ]);
      expect(rows.single.points, 12);
    });
  });

  group('LeaderboardEntry', () {
    test('a blank name falls back to Member, and initials never empty', () {
      final e = leaderboardFromJson([
        {..._row(1, 'a'), 'name': '  '},
      ]).single;
      expect(e.displayName, 'Member');
      expect(e.initials, 'M');
    });

    test('initials are the first letters of the first two words', () {
      final e = leaderboardFromJson([
        {..._row(1, 'a'), 'name': 'sara bint ahmed'},
      ]).single;
      expect(e.initials, 'SB');
    });
  });

  group('LeaderboardRepositoryImpl', () {
    test('success carries the rows and asks for that group', () async {
      final remote = _Remote(rows: leaderboardFromJson([_row(1, 'a')]));
      final result = await LeaderboardRepositoryImpl(remote).leaderboard('g1');
      expect(result, isA<Success<List<LeaderboardEntry>>>());
      expect(remote.asked, 'g1');
    });

    Future<Failure> failureOf(Object error) async {
      final result = await LeaderboardRepositoryImpl(
        _Remote(error: error),
      ).leaderboard('g1');
      return (result as Error<List<LeaderboardEntry>>).failure;
    }

    test('no connection', () async {
      expect(await failureOf(const NetworkException()), isA<NetworkFailure>());
    });

    test('group not found', () async {
      expect(
        await failureOf(const NotFoundException()),
        isA<NotFoundFailure>(),
      );
    });

    test('a server error keeps its message', () async {
      final f = await failureOf(const ServerException('Not a member'));
      expect(f, isA<ServerFailure>());
      expect(f.message, 'Not a member');
    });

    test('anything else is unexpected', () async {
      expect(await failureOf(StateError('x')), isA<UnexpectedFailure>());
    });
  });
}
