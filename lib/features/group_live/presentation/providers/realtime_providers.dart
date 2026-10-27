import '../../../../core/utils/flow_log.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../streaks/presentation/providers/streaks_providers.dart';
import '../../data/realtime_socket.dart';
import '../../domain/realtime_event.dart';
import 'group_live_store.dart';
import 'realtime_service.dart';

/// Overridden in tests with a fake socket.
final realtimeSocketFactoryProvider = Provider<RealtimeSocketFactory>(
  (ref) => createSocketIoRealtimeSocket,
);

/// For the "live / reconnecting" indicator.
final liveStatusProvider = StateProvider<LiveStatus>(
  (ref) => LiveStatus.offline,
);

/// The one live connection, for the signed-in user: created at sign-in,
/// disposed at sign-out (or when another account signs in). Null for a guest.
final realtimeServiceProvider = Provider<RealtimeService?>((ref) {
  final userId = ref.watch(authSessionProvider.select((s) => s.userId));
  if (userId == null) return null;

  final status = ref.read(liveStatusProvider.notifier);
  late final RealtimeService service;
  service = RealtimeService(
    url: ApiEndpoints.realtime,
    socketFactory: ref.watch(realtimeSocketFactoryProvider),
    tokenProvider: () => ref.read(tokenStorageProvider).readAccessToken(),
    onStatus: (s) => Future.microtask(() {
      try {
        status.state = s;
      } on StateError {
        // The container is already gone (app shutdown).
      }
    }),
    onEvent: (e) => _route(ref, e),
    onSubscribed: (groupId) {
      // Subscribed first, summary second: nothing can fall in the gap.
      if (ref.exists(groupLiveProvider(groupId))) {
        unawaited(ref.read(groupLiveProvider(groupId).notifier).refresh());
      }
    },
    onForbidden: (groupId) {
      ref.read(myGroupsProvider.notifier).dropLocally(groupId);
    },
    onUnauthorized: () {
      // The token is refused and there is no refresh call. Ask the server who
      // we are: a dead token answers 401, which ends the session.
      unawaited(ref.read(authSessionProvider.notifier).refresh());
    },
  );

  // Subscribe to every group the user is in (the service keeps to the
  // server's 20-per-socket cap, groups on screen first).
  ref.listen(myGroupsProvider, (_, next) {
    final groups = next.valueOrNull;
    if (groups != null) service.setMemberGroups([for (final g in groups) g.id]);
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  service.start();
  return service;
});

/// What each live event means for the app. The numbers pipeline lives in the
/// group's store; this adds the app-wide effects of `group.changed`.
void _route(Ref ref, RealtimeEvent event) {
  final live = groupLiveProvider(event.groupId);
  final open = ref.exists(live);
  FlowLog.log(
    'REALTIME',
    'ROUTING ${event.runtimeType} for group ${FlowLog.mask(event.groupId)} '
        '(${open ? 'its screen is open: applying' : 'no screen open for it'})',
  );
  if (open) ref.read(live.notifier).apply(event);

  if (event is! GroupChangedEvent) return;
  switch (event.reason) {
    case GroupChangeReason.groupUpdated:
      // Name, description or picture.
      ref.invalidate(groupDetailProvider(event.groupId));
      ref.invalidate(myGroupsProvider);
    case GroupChangeReason.groupDeleted:
      // The store (if the group is open) marks it gone; the list drops it
      // either way, and nothing more arrives for it.
      ref.read(realtimeServiceProvider)?.forget(event.groupId);
      ref.read(myGroupsProvider.notifier).dropLocally(event.groupId);
    case GroupChangeReason.roleChanged:
      ref.invalidate(groupDetailProvider(event.groupId));
      ref.invalidate(myGroupsProvider);
    case GroupChangeReason.ruleChanged:
      ref.invalidate(streakRuleProvider(event.groupId));
    case GroupChangeReason.memberJoined:
    case GroupChangeReason.memberLeft:
    case GroupChangeReason.memberRemoved:
    case GroupChangeReason.unknown:
      // The member list (names, pictures) lives in the group detail.
      ref.invalidate(groupDetailProvider(event.groupId));
  }
}
