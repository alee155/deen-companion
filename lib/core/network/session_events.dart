import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped by the network layer when the backend rejects the stored access
/// token (expired/revoked). The auth feature listens and ends the session —
/// this indirection keeps `core/` from depending on a feature.
final unauthorizedEventProvider = StateProvider<int>((ref) => 0);
