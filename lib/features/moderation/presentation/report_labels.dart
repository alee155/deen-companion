import '../domain/entities/report_reason.dart';
import '../domain/entities/report_target.dart';

/// The wording for each [ReportReason]: a title, and one line that says what
/// it covers so people pick the right one.
extension ReportReasonText on ReportReason {
  String get title => switch (this) {
    ReportReason.inappropriate => 'Inappropriate content',
    ReportReason.harassment => 'Harassment or bullying',
    ReportReason.spam => 'Spam or a scam',
    ReportReason.impersonation => 'Pretending to be someone else',
    ReportReason.other => 'Something else',
  };

  String get hint => switch (this) {
    ReportReason.inappropriate => 'Nudity, violence or anything unsuitable',
    ReportReason.harassment => 'Insults, threats or targeting someone',
    ReportReason.spam => 'Unwanted promotion or misleading links',
    ReportReason.impersonation => 'A fake name or picture',
    ReportReason.other => 'Tell us more in the note below',
  };
}

extension ReportTargetText on ReportTarget {
  bool get isSnap => this is ReportSnapTarget;

  String get sheetTitle => isSnap ? 'Report snap' : 'Report $userName';

  String get sheetSubtitle =>
      isSnap ? 'A snap from $userName' : 'Tell us what’s wrong.';
}
