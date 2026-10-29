import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../auth/domain/entities/gender.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../special_days/presentation/providers/special_days_providers.dart';
import 'profile_providers.dart';

/// The user closed the prompt without answering. Held for this run of the app
/// only, so it asks again next time rather than nagging in one session.
final genderPromptDismissedProvider = StateProvider<bool>((ref) => false);

/// Whether to ask for the gender now: signed in, profile read, and none set.
/// Accounts made since the field was added have one from sign-up.
final genderPromptNeededProvider = Provider<bool>((ref) {
  if (ref.watch(genderPromptDismissedProvider)) return false;
  final profile = ref.watch(profileProvider).valueOrNull;
  return profile != null && profile.gender == null;
});

class GenderPromptState {
  final bool isSaving;
  final String? errorMessage;
  const GenderPromptState({this.isSaving = false, this.errorMessage});
}

/// Saves the answer. The server accepts it once and for good.
class GenderPromptController extends AutoDisposeNotifier<GenderPromptState> {
  @override
  GenderPromptState build() => const GenderPromptState();

  /// True once the account has a gender (this call set it, or it was already
  /// set, which comes to the same thing).
  Future<bool> save(Gender gender) async {
    if (state.isSaving) return false;
    state = const GenderPromptState(isSaving: true);
    final result = await ref.read(profileRepositoryProvider).setGender(gender);
    final ok = switch (result) {
      Success() => true,
      Error(:final failure) => failure is GenderAlreadySet,
    };
    if (ok) {
      // The profile now carries it; whether special days apply follows.
      ref.invalidate(profileProvider);
      ref.invalidate(specialDaysProvider);
      state = const GenderPromptState();
      return true;
    }
    state = GenderPromptState(
      errorMessage: switch (result) {
        Error(:final failure) => failure.message,
        _ => null,
      },
    );
    return false;
  }
}

final genderPromptControllerProvider =
    NotifierProvider.autoDispose<GenderPromptController, GenderPromptState>(
      GenderPromptController.new,
    );
