import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/features/group_live/data/group_summary_remote_datasource.dart';

/// A scriptable summary endpoint. By default it is "unreachable", so a screen
/// under test falls back to the plain streak board, as it does offline.
class FakeSummaryRemote implements GroupSummaryRemoteDataSource {
  /// What the next call returns; throws when null.
  Future<SummaryResponse> Function(String groupId, String? etag)? handler;
  final calls = <({String groupId, String? etag})>[];

  @override
  Future<SummaryResponse> fetch(String groupId, {String? etag}) {
    calls.add((groupId: groupId, etag: etag));
    final h = handler;
    if (h == null) throw const NetworkException();
    return h(groupId, etag);
  }
}
