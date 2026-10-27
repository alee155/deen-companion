import 'package:equatable/equatable.dart';

/// Why the app believes it has no internet.
enum OfflineReason {
  /// The phone itself reports no network (airplane mode, Wi-Fi and mobile
  /// data off, mobile data blocked for this app).
  noInterface,

  /// A network is up but nothing gets through: a captive portal, a dead
  /// router, or our server is down.
  unreachable,
}

/// What the app currently believes about its internet connection.
///
/// "Online" is the default and the benefit of the doubt: the app only says
/// it is offline when it has good reason to, because a false "offline" is
/// worse than a missing one (it hides a working app behind an error).
class ConnectivityState extends Equatable {
  /// Null while online.
  final OfflineReason? reason;

  /// A check is running (the user tapped retry, or the connection just
  /// came back and is being confirmed).
  final bool isChecking;

  const ConnectivityState.online({this.isChecking = false}) : reason = null;

  const ConnectivityState.offline(
    OfflineReason this.reason, {
    this.isChecking = false,
  });

  bool get isOnline => reason == null;
  bool get isOffline => reason != null;

  ConnectivityState copyWith({bool? isChecking}) => isOffline
      ? ConnectivityState.offline(
          reason!,
          isChecking: isChecking ?? this.isChecking,
        )
      : ConnectivityState.online(isChecking: isChecking ?? this.isChecking);

  @override
  List<Object?> get props => [reason, isChecking];
}
