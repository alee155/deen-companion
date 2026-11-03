import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecase/usecase.dart';
import 'auth_gate_provider.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

enum SocialProvider { google, apple }

class SocialAuthState {
  /// The provider whose sheet or request is open, or null.
  final SocialProvider? busy;
  final String? errorMessage;

  const SocialAuthState({this.busy, this.errorMessage});

  bool get isBusy => busy != null;
}

enum SocialOutcome {
  /// The session is active.
  signedIn,

  /// The person closed the sheet: nothing to show.
  cancelled,

  /// See [SocialAuthState.errorMessage].
  failed,
}

/// Google and Apple sign-in from the login and sign-up screens. A new account
/// has no gender yet; the one-time gender prompt asks for it once the person is
/// in the app, the same as for any account without one.
class SocialAuthController extends Notifier<SocialAuthState> {
  @override
  SocialAuthState build() => const SocialAuthState();

  Future<SocialOutcome> signIn(SocialProvider provider) async {
    if (state.isBusy) return SocialOutcome.cancelled;
    state = SocialAuthState(busy: provider);
    final repo = ref.read(authRepositoryProvider);
    final result = switch (provider) {
      SocialProvider.google => await repo.signInWithGoogle(),
      SocialProvider.apple => await repo.signInWithApple(),
    };
    switch (result) {
      case Success(:final data):
        if (data == null) {
          state = const SocialAuthState();
          return SocialOutcome.cancelled;
        }
        await ref
            .read(authSessionProvider.notifier)
            .signIn(data.user.toSession());
        await ref.read(authGateProvider).markSeen();
        state = const SocialAuthState();
        return SocialOutcome.signedIn;
      case Error(:final failure):
        state = SocialAuthState(errorMessage: failure.message);
        return SocialOutcome.failed;
    }
  }
}

final socialAuthControllerProvider =
    NotifierProvider<SocialAuthController, SocialAuthState>(
      SocialAuthController.new,
    );

/// Whether to show the Apple button: iPhone only.
final appleSignInSupportedProvider = Provider<bool>(
  (ref) => ref.watch(authRepositoryProvider).appleSignInSupported,
);
