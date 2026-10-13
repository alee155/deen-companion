import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

class DeleteAccountState {
  final bool isDeleting;
  final String? errorMessage;

  const DeleteAccountState({this.isDeleting = false, this.errorMessage});
}

class DeleteAccountController extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() => const DeleteAccountState();

  /// Deletes the account server-side, then ends the local session. Returns
  /// true on success. If the server call fails the user stays signed in.
  Future<bool> delete() async {
    if (state.isDeleting) return false;
    state = const DeleteAccountState(isDeleting: true);
    final result = await ref.read(authRepositoryProvider).deleteAccount();
    var succeeded = false;
    state = result.when(
      success: (_) {
        succeeded = true;
        return const DeleteAccountState();
      },
      failure: (f) => DeleteAccountState(errorMessage: f.message),
    );
    if (succeeded) await ref.read(authSessionProvider.notifier).signOut();
    return succeeded;
  }
}

final deleteAccountControllerProvider =
    NotifierProvider<DeleteAccountController, DeleteAccountState>(
      DeleteAccountController.new,
    );
