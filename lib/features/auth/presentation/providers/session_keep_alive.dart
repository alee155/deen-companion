import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/keep_alive_for.dart';
import 'auth_session_provider.dart';

/// [keepAliveFor], plus: the data is dropped at once when another account
/// signs in, so one person's numbers (and the names on a board) are never
/// shown to the next. Use it for any auto-dispose provider holding
/// account-specific data.
KeepAliveLink keepAliveForSession(Ref<Object?> ref, Duration ttl) {
  final link = keepAliveFor(ref, ttl);
  ref.listen(authSessionProvider.select((s) => s.userId), (_, _) {
    link.close();
  });
  return link;
}
