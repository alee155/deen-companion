import 'package:equatable/equatable.dart';

/// Something a user can report: a person, or one of their snaps.
sealed class ReportTarget extends Equatable {
  /// The person responsible, always known: it is who a report is about, and
  /// who the user is offered to block afterwards.
  final String userId;
  final String userName;

  const ReportTarget({required this.userId, required this.userName});
}

/// Reporting a person (their name, picture, behaviour).
class ReportUserTarget extends ReportTarget {
  const ReportUserTarget({required super.userId, required super.userName});

  @override
  List<Object?> get props => [userId, userName];
}

/// Reporting one snap (the photo itself).
class ReportSnapTarget extends ReportTarget {
  /// The prayer log the snap belongs to.
  final String snapId;

  const ReportSnapTarget({
    required this.snapId,
    required super.userId,
    required super.userName,
  });

  @override
  List<Object?> get props => [snapId, userId, userName];
}
