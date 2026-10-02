import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';

/// Marks the Welcome/auth gate as passed, so Splash sends the user straight
/// to Home on every later launch. Called on "Continue as guest" now; once
/// the real backend lands, a successful login/signup should call this too.
final authGateProvider = Provider((ref) => AuthGate(ref));

class AuthGate {
  final Ref _ref;
  const AuthGate(this._ref);

  Future<void> markSeen() {
    return _ref
        .read(localStorageServiceProvider)
        .put(AppConstants.settingsBoxName, AppConstants.authGateSeenKey, true);
  }
}
