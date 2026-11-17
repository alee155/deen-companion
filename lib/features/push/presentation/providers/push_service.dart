// The backend pushes to the classic FCM token. firebase_messaging 17 marks
// getToken / onTokenRefresh / deleteToken deprecated in favour of an
// Installation ID (a different identifier the server does not use), so the
// deprecated calls are the right ones here.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../../../firebase_options.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../daily_content/data/daily_notification_scheduler.dart';
import '../../../daily_content/presentation/providers/daily_content_providers.dart';
import '../../../group_live/presentation/providers/realtime_providers.dart';
import '../../data/push_remote_datasource.dart';

const _tag = 'PUSH';

/// Runs when a push arrives while the app is in the background or closed. The
/// OS shows the notification itself (the server sends a notification message),
/// so there is nothing to do here; it only has to exist, be top level, and be
/// registered in `bootstrap.dart`.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final pushRemoteDataSourceProvider = Provider<PushRemoteDataSource>(
  (ref) => PushRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// Keeps push in step with the account: started with the app, registers this
/// phone when someone is signed in, forgets it at sign-out. Watched from
/// `app.dart`.
final pushLifecycleProvider = Provider<void>((ref) {
  final push = ref.read(pushServiceProvider)..start();
  ref.listen<String?>(authSessionProvider.select((s) => s.userId), (
    previous,
    next,
  ) {
    if (next != null) {
      unawaited(push.onSignedIn());
    } else if (previous != null) {
      unawaited(push.onSignedOut());
    }
  }, fireImmediately: true);
});

/// Push notifications for group snaps: gets this phone's FCM token to the
/// backend, shows a banner for a snap in a group other than the one on screen
/// while the app is open, and opens the group when a push is tapped.
///
/// Never throws into the app: every failure is logged and push simply does
/// not work until the next try (app start, sign-in or token refresh).
class PushService {
  final Ref _ref;
  PushService(this._ref);

  /// The Android channel the server sends to. Must match the backend.
  static const snapsChannelId = 'snaps';
  static const _snapType = 'snap_shared';

  bool _started = false;
  bool _routerReady = false;
  bool _registering = false;
  String? _pendingGroupId;
  StreamSubscription<String>? _refreshSub;

  DailyNotificationScheduler get _scheduler =>
      _ref.read(dailyNotificationSchedulerProvider);

  /// False when Firebase failed to start (see `bootstrap.dart`).
  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  /// Call once at launch: creates the channel and starts listening for taps
  /// and foreground messages.
  void start() {
    if (_started || !_firebaseReady) return;
    _started = true;
    try {
      final fcm = FirebaseMessaging.instance;
      // The app shows its own banner in the foreground (and only for a group
      // that is not on screen), so the OS must not show the push too.
      unawaited(
        fcm.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        ),
      );
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      _scheduler.onSnapTap = _openGroup;
      unawaited(_createChannel());
      unawaited(
        fcm.getInitialMessage().then((m) {
          if (m != null) _openFromMessage(m);
        }),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Push start failed', error, stackTrace);
    }
  }

  // ── Channel ─────────────────────────────────────────────────────────────

  /// Android 8+ shows a push on a channel the app created; the server targets
  /// [snapsChannelId]. Without it the push falls back to a generic channel.
  Future<void> _createChannel() async {
    if (!Platform.isAndroid) return;
    try {
      await _scheduler.whenReady();
      await _scheduler.plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              snapsChannelId,
              'Snaps',
              description: 'A group member shared a snap',
              importance: Importance.high,
            ),
          );
    } catch (error, stackTrace) {
      AppLogger.e('Push: creating the snaps channel failed', error, stackTrace);
    }
  }

  // ── Token ───────────────────────────────────────────────────────────────

  /// Someone is signed in (just now, or restored at launch): ask for
  /// permission and tell the backend which phone to push to.
  Future<void> onSignedIn() async {
    if (!_firebaseReady || _registering) return;
    _registering = true;
    try {
      final fcm = FirebaseMessaging.instance;
      final settings = await fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        FlowLog.log(_tag, 'NOTIFICATIONS DENIED -> not registering this phone');
        return;
      }

      if (Platform.isIOS) {
        // iOS hands out the FCM token only after Apple has given the APNs
        // token, which can take a moment after the permission is granted.
        for (var i = 0; i < 10 && await fcm.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = await fcm.getToken();
      if (token != null) await _send(token);
      // The token rotates now and then: send the new one each time.
      _refreshSub ??= fcm.onTokenRefresh.listen(
        _send,
        onError: (Object e) => AppLogger.e('Push: token refresh failed', e),
      );
      unawaited(_deliverPending());
    } catch (error, stackTrace) {
      AppLogger.e('Push registration failed', error, stackTrace);
    } finally {
      _registering = false;
    }
  }

  Future<void> _send(String token) async {
    if (!_ref.read(authSessionProvider).isAuthenticated) return;
    try {
      await _ref
          .read(pushRemoteDataSourceProvider)
          .register(token: token, platform: Platform.isIOS ? 'ios' : 'android');
      FlowLog.log(
        _tag,
        'PHONE REGISTERED for push (token ${token.length} chars)',
      );
    } catch (error, stackTrace) {
      // Tried again at the next app start or token refresh.
      AppLogger.e('Push: registering the token failed', error, stackTrace);
    }
  }

  /// The user chose to log out: tell the backend while the session is still
  /// valid, so the next person on this phone never gets this user's pushes.
  /// Offline or failing is fine, the log out goes ahead either way.
  Future<void> unregister() async {
    if (!_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 3),
      );
      if (token == null) return;
      await _ref
          .read(pushRemoteDataSourceProvider)
          .unregister(token)
          .timeout(const Duration(seconds: 5));
      FlowLog.log(_tag, 'PHONE UNREGISTERED from push');
    } catch (error) {
      AppLogger.e('Push: unregistering the token failed', error);
    }
  }

  /// The session ended (log out, deleted account, or an expired token): drop
  /// this phone's token so the old account's pushes can no longer reach it.
  /// The next sign-in gets a fresh one.
  Future<void> onSignedOut() async {
    if (!_firebaseReady) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      AppLogger.e('Push: deleting the token failed', error);
    }
  }

  // ── Foreground ──────────────────────────────────────────────────────────

  /// A push arrived while the app is open. A snap in a group the user is not
  /// looking at gets a banner; one for the open group is already in its feed.
  void _onForegroundMessage(RemoteMessage message) {
    if (message.data['type'] != _snapType) return;
    final groupIds = _groupIds(message.data);
    if (groupIds.isEmpty) return;
    final live = _ref.read(realtimeServiceProvider);
    if (live != null && groupIds.any(live.isViewing)) return;

    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;
    unawaited(_showBanner(groupIds.first, title, body));
  }

  Future<void> _showBanner(String groupId, String? title, String? body) async {
    try {
      await _scheduler.whenReady();
      await _scheduler.plugin.show(
        // One banner per group: a newer snap replaces the older one.
        id: groupId.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            snapsChannelId,
            'Snaps',
            channelDescription: 'A group member shared a snap',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_logo',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            threadIdentifier: groupId,
          ),
        ),
        payload: '${DailyNotificationScheduler.snapPayloadPrefix}$groupId',
      );
    } catch (error, stackTrace) {
      AppLogger.e('Push: showing the banner failed', error, stackTrace);
    }
  }

  // ── Taps ────────────────────────────────────────────────────────────────

  static List<String> _groupIds(Map<String, dynamic> data) {
    final first = data['groupId'];
    final many = data['groupIds'];
    return <String>{
      if (first is String && first.isNotEmpty) first,
      if (many is String)
        ...many.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
    }.toList();
  }

  void _openFromMessage(RemoteMessage message) {
    if (message.data['type'] != _snapType) return;
    final groupId = message.data['groupId'];
    if (groupId is String && groupId.isNotEmpty) _openGroup(groupId);
  }

  /// Home is up (after the splash and the welcome gate): a tap queued during
  /// launch can now be opened.
  void onHomeReady() {
    _routerReady = true;
    unawaited(_deliverPending());
  }

  void _openGroup(String groupId) {
    _pendingGroupId = groupId;
    unawaited(_deliverPending());
  }

  /// Opens the queued group once the router can take it and someone is signed
  /// in; otherwise keeps it for later (cold start, or tapped while signed out).
  Future<void> _deliverPending() async {
    final groupId = _pendingGroupId;
    if (groupId == null || !_routerReady) return;
    if (!_ref.read(authSessionProvider).isAuthenticated) return;
    _pendingGroupId = null;
    final router = _ref.read(appRouterProvider);
    final target = '/groups/${Uri.encodeComponent(groupId)}';
    if (router.routerDelegate.currentConfiguration.uri.path == target) return;
    FlowLog.log(_tag, 'OPENING GROUP from a push');
    router.push(target);
  }
}
