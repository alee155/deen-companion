import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../data/realtime_socket.dart';
import '../../domain/realtime_event.dart';

const _tag = 'REALTIME';

/// What the "live" indicator shows.
enum LiveStatus {
  /// Not connected and not trying (backgrounded, signed out, or stopped).
  offline,
  connecting,
  live,

  /// The connection dropped; the library is retrying.
  reconnecting,

  /// The server refused the token; nothing retries until the app resumes.
  unauthorized,
}

/// The server's cap on client events per socket per minute (it disconnects the
/// socket above 30). Stay under it so a reconnect storm cannot trip it.
const _emitsPerMinute = 25;

/// The server's cap on group subscriptions per socket.
const maxGroupSubscriptions = 20;

/// One live connection to the group events namespace, for one signed-in user.
///
/// Created after sign-in and disposed on sign-out. It owns the socket, keeps
/// subscriptions right across reconnects, and hands parsed, de-duplicated
/// events to [onEvent]. It never decides what an event means for the UI.
class RealtimeService with WidgetsBindingObserver {
  final String url;
  final RealtimeSocketFactory socketFactory;
  final Future<String?> Function() tokenProvider;

  /// Every new event, once (by `eventId`).
  final void Function(RealtimeEvent event) onEvent;

  /// A group is subscribed on the current socket: fetch its summary now (the
  /// summary comes after the subscription, so nothing falls in the gap).
  final void Function(String groupId) onSubscribed;

  /// The server says the caller is not a member of [groupId].
  final void Function(String groupId) onForbidden;

  /// The server refused the token.
  final void Function() onUnauthorized;
  final void Function(LiveStatus status) onStatus;

  final DateTime Function() clock;
  final Random _random;

  RealtimeService({
    required this.url,
    required this.socketFactory,
    required this.tokenProvider,
    required this.onEvent,
    required this.onSubscribed,
    required this.onForbidden,
    required this.onUnauthorized,
    required this.onStatus,
    DateTime Function()? clock,
    Random? random,
  }) : clock = clock ?? DateTime.now,
       _random = random ?? Random();

  RealtimeSocket? _socket;
  bool _disposed = false;
  bool _started = false;
  bool _foreground = true;
  LiveStatus _status = LiveStatus.offline;

  /// Groups the user is looking at (always subscribed), and the user's other
  /// groups (subscribed while there is room).
  final Set<String> _watched = {};
  List<String> _memberOf = const [];
  final Set<String> _forbidden = {};

  /// Subscribed on the *current* socket. Cleared on every disconnect:
  /// subscriptions do not survive a reconnect.
  final Set<String> _subscribed = {};
  final Set<String> _pending = {};
  final Map<String, int> _retries = {};

  final Set<String> _seenEvents = {};
  static const _seenCap = 300;

  final List<DateTime> _emitTimes = [];
  final List<void Function()> _emitQueue = [];
  Timer? _pump;
  Timer? _reconnectTimer;
  DateTime? _lastServerDropRetry;

  LiveStatus get status => _status;

  void _setStatus(LiveStatus s) {
    if (_status == s) return;
    FlowLog.log(_tag, 'STATUS ${_status.name} -> ${s.name}');
    _status = s;
    onStatus(s);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_connect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // The OS kills a backgrounded socket anyway; close it cleanly. Events
        // missed meanwhile are never replayed, the summary covers them.
        _foreground = false;
        _closeSocket();
        _setStatus(LiveStatus.offline);
      case AppLifecycleState.resumed:
        if (_foreground) return;
        _foreground = true;
        unawaited(_connect());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _pump?.cancel();
    _reconnectTimer?.cancel();
    _emitQueue.clear();
    _closeSocket();
    _seenEvents.clear();
    _watched.clear();
    _setStatus(LiveStatus.offline);
  }

  void _closeSocket() {
    _reconnectTimer?.cancel();
    _emitQueue.clear();
    _pump?.cancel();
    _subscribed.clear();
    _pending.clear();
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.disconnect();
      socket.dispose();
    }
  }

  // ── Connecting ──────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (_disposed || !_foreground) return;
    _closeSocket();
    final token = await tokenProvider();
    if (_disposed || !_foreground) return;
    if (token == null || token.isEmpty) {
      FlowLog.log(_tag, 'NOT CONNECTING: no access token saved');
      _setStatus(LiveStatus.offline);
      return;
    }
    FlowLog.log(
      _tag,
      'CONNECTING to $url (websocket only, token present, ${token.length} chars)',
    );
    _setStatus(LiveStatus.connecting);
    final socket = socketFactory(url, tokenProvider);
    _socket = socket;
    socket.onConnect(() {
      if (_socket != socket) return;
      FlowLog.log(_tag, 'CONNECTED -> subscribing to the groups');
      _setStatus(LiveStatus.live);
      _subscribed.clear();
      _pending.clear();
      _syncSubscriptions();
    });
    socket.onConnectError((message) {
      if (_socket != socket) return;
      FlowLog.log(_tag, 'CONNECT ERROR: $message');
      if (message == 'unauthorized') {
        // A new token is the only fix and the library does not retry this:
        // do not loop. The session check (REST) ends the session if the token
        // is really dead.
        _setStatus(LiveStatus.unauthorized);
        _closeSocket();
        onUnauthorized();
      } else {
        _setStatus(LiveStatus.reconnecting);
      }
    });
    socket.onDisconnect((reason) {
      if (_socket != socket) return;
      FlowLog.log(_tag, 'DISCONNECTED: $reason');
      _subscribed.clear();
      _pending.clear();
      _emitQueue.clear();
      if (reason == 'io client disconnect') return;
      if (reason == 'io server disconnect') {
        // Token expired, oldest of the user's sockets, or too many events: the
        // library will not reconnect. Try once with a fresh token, never in a
        // loop (and never straight away: another device may be the cause).
        _setStatus(LiveStatus.offline);
        _scheduleSingleReconnect();
      } else {
        _setStatus(LiveStatus.reconnecting);
      }
    });
    for (final name in const [
      prayerLoggedEventName,
      prayerDeletedEventName,
      groupChangedEventName,
    ]) {
      socket.onEvent(name, (data) => _handle(name, data));
    }
    socket.connect();
  }

  void _scheduleSingleReconnect() {
    final now = clock();
    final last = _lastServerDropRetry;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      FlowLog.log(
        _tag,
        'DROPPED BY THE SERVER AGAIN within a minute -> staying offline',
      );
      return;
    }
    FlowLog.log(_tag, 'DROPPED BY THE SERVER -> one reconnect in a moment');
    _lastServerDropRetry = now;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(milliseconds: 1000 + _random.nextInt(2000)),
      () => unawaited(_connect()),
    );
  }

  // ── Subscriptions ───────────────────────────────────────────────────────

  /// Marks [groupId] as on screen: subscribed even when the user is in more
  /// groups than one socket can hold.
  void watch(String groupId) {
    if (_disposed || !_watched.add(groupId)) return;
    _syncSubscriptions();
  }

  void unwatch(String groupId) {
    if (_disposed || !_watched.remove(groupId)) return;
    _syncSubscriptions();
  }

  /// The ids of every group the user is in.
  void setMemberGroups(Iterable<String> groupIds) {
    if (_disposed) return;
    _memberOf = groupIds.toList();
    _syncSubscriptions();
  }

  /// The group is gone for this user (deleted, or they were removed): stop
  /// listening to it.
  void forget(String groupId) {
    if (_disposed) return;
    _forbidden.add(groupId);
    _watched.remove(groupId);
    _memberOf = [
      for (final id in _memberOf)
        if (id != groupId) id,
    ];
    _syncSubscriptions();
  }

  List<String> _desired() {
    final ids = <String>[
      ..._watched,
      for (final id in _memberOf)
        if (!_watched.contains(id)) id,
    ]..removeWhere(_forbidden.contains);
    return ids.take(maxGroupSubscriptions).toList();
  }

  void _syncSubscriptions() {
    final socket = _socket;
    if (socket == null || _status != LiveStatus.live) return;
    final desired = _desired().toSet();
    FlowLog.log(
      _tag,
      'SYNC SUBSCRIPTIONS wanted ${desired.length}, held ${_subscribed.length}',
    );
    for (final id in _subscribed.toList()) {
      if (desired.contains(id)) continue;
      _subscribed.remove(id);
      _send(
        () => socket.emitWithAck('group.unsubscribe', {'groupId': id}, (_) {}),
      );
    }
    for (final id in desired) {
      if (_subscribed.contains(id) || !_pending.add(id)) continue;
      _send(() => _subscribe(socket, id));
    }
  }

  void _subscribe(RealtimeSocket socket, String groupId) {
    FlowLog.log(_tag, 'SUBSCRIBE group ${FlowLog.mask(groupId)} (asking)');
    socket.emitWithAck('group.subscribe', {'groupId': groupId}, (ack) {
      if (_socket != socket) return;
      _pending.remove(groupId);
      final ok = ack is Map && ack['ok'] == true;
      FlowLog.log(
        _tag,
        'SUBSCRIBE ANSWER for group ${FlowLog.mask(groupId)}: $ack',
      );
      if (ok) {
        _retries.remove(groupId);
        _subscribed.add(groupId);
        onSubscribed(groupId);
        return;
      }
      final error = ack is Map ? ack['error'] : null;
      switch (error) {
        case 'forbidden':
          // Not a member (left, removed, or the group is gone).
          forget(groupId);
          onForbidden(groupId);
        case 'limit':
          // Too many on this socket: keep only what is on screen.
          _memberOf = const [];
          _syncSubscriptions();
        case 'internal':
          _retrySubscribe(groupId);
        default:
          AppLogger.e('Realtime: subscribe rejected ($error) for $groupId');
      }
    });
  }

  void _retrySubscribe(String groupId) {
    final attempt = (_retries[groupId] ?? 0) + 1;
    _retries[groupId] = attempt;
    if (attempt > 5) return;
    final delay = Duration(seconds: min(60, 2 << attempt));
    Timer(delay, () {
      if (_disposed || _subscribed.contains(groupId)) return;
      _syncSubscriptions();
    });
  }

  // ── Client events, paced ────────────────────────────────────────────────

  /// Runs [emit] now if the per-minute budget allows, else a little later.
  void _send(void Function() emit) {
    _emitQueue.add(emit);
    _drain();
  }

  void _drain() {
    final now = clock();
    _emitTimes.removeWhere(
      (t) => now.difference(t) >= const Duration(minutes: 1),
    );
    while (_emitQueue.isNotEmpty && _emitTimes.length < _emitsPerMinute) {
      _emitTimes.add(now);
      _emitQueue.removeAt(0)();
    }
    _pump?.cancel();
    if (_emitQueue.isNotEmpty && !_disposed) {
      final wait =
          const Duration(minutes: 1) - now.difference(_emitTimes.first);
      _pump = Timer(wait + const Duration(milliseconds: 50), _drain);
    }
  }

  // ── Incoming events ─────────────────────────────────────────────────────

  void _handle(String name, Object? data) {
    if (_disposed) return;
    FlowLog.log(_tag, 'EVENT RECEIVED $name');
    final event = parseRealtimeEvent(name, data);
    if (event == null) {
      FlowLog.log(
        _tag,
        'EVENT IGNORED: $name is not in the documented shape: $data',
      );
      return;
    }
    if (!_seenEvents.add(event.eventId)) {
      FlowLog.log(
        _tag,
        'EVENT IGNORED: $name already seen (${FlowLog.mask(event.eventId)})',
      );
      return;
    }
    FlowLog.log(
      _tag,
      'EVENT OK $name group ${FlowLog.mask(event.groupId)} emitted ${event.emittedAt.toIso8601String()}',
    );
    if (_seenEvents.length > _seenCap) {
      _seenEvents.remove(_seenEvents.first);
    }
    onEvent(event);
  }
}
