import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../domain/entities/snap_draft.dart';
import '../../domain/repositories/snap_repository.dart';

/// SIMULATED sending — nothing is uploaded. It only mimics latency so the
/// whole flow (progress, success) can be built and reviewed.
///
/// No longer used by the app: `snapRepositoryProvider` now points at
/// `PrayerLogSnapRepository` (the real `POST /prayers/logs`). Kept for previews
/// and as a stand-in when the backend is unavailable.
class MockSnapRepository implements SnapRepository {
  const MockSnapRepository();

  @override
  Future<Result<SentSnap>> sendSnap(SnapDraft draft) async {
    FlowLog.log(
      'SEND SNAP',
      'SIMULATED SEND - NO API IS CALLED, so there is no server response. '
          'The photo is not uploaded.',
    );
    FlowLog.data('SEND SNAP', 'what would have been sent', {
      'groupId': draft.groupId,
      'recipients': draft.recipientIds.length,
      'viewSeconds': draft.viewSeconds,
      'hasCaption': draft.caption != null,
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final snap = SentSnap(id: 'mock-${DateTime.now().millisecondsSinceEpoch}');
    FlowLog.log('SEND SNAP', 'SIMULATED RESULT: success (id ${snap.id})');
    return Success(snap);
  }
}
