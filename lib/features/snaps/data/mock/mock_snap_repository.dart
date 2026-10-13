import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/snap_draft.dart';
import '../../domain/repositories/snap_repository.dart';

/// SIMULATED sending — nothing is uploaded. It only mimics latency so the
/// whole flow (progress, success) can be built and reviewed.
///
/// TODO(snaps-backend): delete this and implement [SnapRepository] against the
/// real POST API (multipart upload of [SnapDraft.imagePath] plus viewSeconds,
/// caption and recipients), then point `snapRepositoryProvider` at it.
class MockSnapRepository implements SnapRepository {
  const MockSnapRepository();

  @override
  Future<Result<SentSnap>> sendSnap(SnapDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    return Success(
      SentSnap(id: 'mock-${DateTime.now().millisecondsSinceEpoch}'),
    );
  }
}
