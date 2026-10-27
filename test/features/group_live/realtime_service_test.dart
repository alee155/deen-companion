import 'dart:math';

import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/features/group_live/data/realtime_socket.dart';
import 'package:deen_companion/features/group_live/domain/realtime_event.dart';
import 'package:deen_companion/features/group_live/presentation/providers/realtime_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSocket implements RealtimeSocket {
  void Function()? _connect;
  void Function(String)? _connectError;
  void Function(String)? _disconnect;
  final _events = <String, void Function(Object?)>{};
  final emitted = <({String event, Map<String, dynamic> body})>[];
  final _acks = <void Function(Object?)>[];
  bool connectCalled = false;
  bool disposed = false;

  @override
  void onConnect(void Function() cb) => _connect = cb;
  @override
  void onConnectError(void Function(String) cb) => _connectError = cb;
  @override
  void onDisconnect(void Function(String) cb) => _disconnect = cb;
  @override
  void onEvent(String name, void Function(Object?) cb) => _events[name] = cb;
  @override
  void emitWithAck(
    String event,
    Map<String, dynamic> body,
    void Function(Object?) ack,
  ) {
    emitted.add((event: event, body: body));
    _acks.add(ack);
  }

  @override
  void connect() => connectCalled = true;
  @override
  void disconnect() {}
  @override
  void dispose() => disposed = true;

  // Server side.
  void serverConnects() => _connect!();
  void serverRefuses(String message) => _connectError!(message);
  void serverDrops(String reason) => _disconnect!(reason);
  void serverSends(String name, Object? data) => _events[name]!(data);
  void ackAll(Object? ack) {
    final pending = [..._acks];
    _acks.clear();
    for (final a in pending) {
      a(ack);
    }
  }

  void ackAt(int i, Object? ack) => _acks[i](ack);

  Iterable<String> get subscribedIds => [
    for (final e in emitted)
      if (e.event == 'group.subscribe') e.body['groupId'] as String,
  ];
}

Map<String, dynamic> _changed(String id, String reason) => {
  'eventId': id,
  'emittedAt': '2026-10-22T05:02:11.730Z',
  'groupId': 'g1',
  'reason': reason,
};

class _Harness {
  final FakeAsync async;
  final sockets = <FakeSocket>[];
  final tokens = <String?>[];
  final events = <RealtimeEvent>[];
  final subscribed = <String>[];
  final forbidden = <String>[];
  final statuses = <LiveStatus>[];
  int unauthorized = 0;
  String? token = 'jwt-1';
  late final RealtimeService service;

  _Harness(this.async) {
    final start = DateTime.utc(2026, 10, 22, 10);
    service = RealtimeService(
      url: 'https://host.test/realtime',
      socketFactory: (url, tokenFn) {
        expect(url, 'https://host.test/realtime');
        final s = FakeSocket();
        sockets.add(s);
        tokenFn().then(tokens.add);
        return s;
      },
      tokenProvider: () async => token,
      onEvent: events.add,
      onSubscribed: subscribed.add,
      onForbidden: forbidden.add,
      onUnauthorized: () => unauthorized++,
      onStatus: statuses.add,
      clock: () => start.add(async.elapsed),
      random: Random(1),
    );
  }

  FakeSocket get socket => sockets.last;

  void start() {
    service.start();
    async.flushMicrotasks();
  }

  /// Connect, then let the subscribe acks come back OK.
  void goLive() {
    socket.serverConnects();
    socket.ackAll({'ok': true});
  }
}

void _run(String name, void Function(_Harness h, FakeAsync async) body) {
  test(name, () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FakeAsync().run((async) {
      final h = _Harness(async);
      addTearDown(h.service.dispose);
      body(h, async);
      h.service.dispose();
    });
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  _run(
    'connects with a token and subscribes to the user\'s groups on connect',
    (h, async) {
      h.service.setMemberGroups(['g1', 'g2']);
      h.start();
      expect(h.socket.connectCalled, isTrue);
      expect(h.tokens, ['jwt-1']);
      expect(h.service.status, LiveStatus.connecting);
      // Nothing is sent before the connection is up.
      expect(h.socket.emitted, isEmpty);
      h.socket.serverConnects();
      expect(h.service.status, LiveStatus.live);
      expect(h.socket.subscribedIds, ['g1', 'g2']);
      // The summary is fetched after each subscribe is acknowledged.
      expect(h.subscribed, isEmpty);
      h.socket.ackAll({'ok': true});
      expect(h.subscribed, ['g1', 'g2']);
    },
  );

  _run('no token: it does not connect', (h, async) {
    h.token = null;
    h.start();
    expect(h.sockets, isEmpty);
    expect(h.service.status, LiveStatus.offline);
  });

  _run(
    'subscriptions do not survive a reconnect: every connect subscribes again',
    (h, async) {
      h.service.setMemberGroups(['g1']);
      h.start();
      h.goLive();
      expect(h.subscribed, ['g1']);

      h.socket.serverDrops('transport close'); // library reconnects by itself
      expect(h.service.status, LiveStatus.reconnecting);
      h.socket.emitted.clear();
      h.goLive(); // the library's reconnect: same socket, connect fires again
      expect(h.socket.subscribedIds, ['g1']);
      expect(h.subscribed, ['g1', 'g1']);
    },
  );

  _run('events are de-duplicated by eventId and malformed ones dropped', (
    h,
    async,
  ) {
    h.start();
    h.goLive();
    h.socket.serverSends('group.changed', _changed('e1', 'member_joined'));
    h.socket.serverSends('group.changed', _changed('e1', 'member_joined'));
    h.socket.serverSends('group.changed', _changed('e2', 'member_left'));
    h.socket.serverSends('group.changed', 'garbage');
    expect(h.events.map((e) => e.eventId), ['e1', 'e2']);
  });

  _run('the dedupe set stays bounded', (h, async) {
    h.start();
    h.goLive();
    for (var i = 0; i < 400; i++) {
      h.socket.serverSends('group.changed', _changed('e$i', 'member_joined'));
    }
    expect(h.events, hasLength(400));
    // A recent id is still remembered; one from long ago has aged out.
    h.socket.serverSends('group.changed', _changed('e399', 'member_joined'));
    expect(h.events, hasLength(400));
  });

  _run('unauthorized: no reconnect loop, one session check, status says so', (
    h,
    async,
  ) {
    h.start();
    h.socket.serverRefuses('unauthorized');
    expect(h.unauthorized, 1);
    expect(h.service.status, LiveStatus.unauthorized);
    async.elapse(const Duration(minutes: 10));
    expect(h.sockets, hasLength(1));
    expect(h.socket.disposed, isTrue);
  });

  _run('a network connect error is left to the library to retry', (h, async) {
    h.start();
    h.socket.serverRefuses('websocket error');
    expect(h.service.status, LiveStatus.reconnecting);
    expect(h.unauthorized, 0);
    async.elapse(const Duration(minutes: 1));
    expect(h.sockets, hasLength(1));
  });

  _run(
    'io server disconnect: reconnects once with a fresh token, never in a loop',
    (h, async) {
      h.start();
      h.goLive();
      h.token = 'jwt-2';
      h.socket.serverDrops('io server disconnect');
      expect(h.service.status, LiveStatus.offline);
      // Not straight away.
      expect(h.sockets, hasLength(1));
      async.elapse(const Duration(seconds: 4));
      expect(h.sockets, hasLength(2));
      expect(h.tokens.last, 'jwt-2');

      // Dropped again within the minute: it stays down.
      h.goLive();
      h.socket.serverDrops('io server disconnect');
      async.elapse(const Duration(seconds: 30));
      expect(h.sockets, hasLength(2));
      expect(h.service.status, LiveStatus.offline);
    },
  );

  _run('forbidden on subscribe: the group is forgotten and never retried', (
    h,
    async,
  ) {
    h.service.setMemberGroups(['g1', 'g2']);
    h.start();
    h.socket.serverConnects();
    h.socket.ackAt(0, {'ok': false, 'error': 'forbidden'});
    h.socket.ackAt(1, {'ok': true});
    expect(h.forbidden, ['g1']);
    expect(h.subscribed, ['g2']);
    // A reconnect subscribes to g2 only.
    h.socket.serverDrops('transport close');
    h.socket.emitted.clear();
    h.goLive();
    expect(h.socket.subscribedIds, ['g2']);
  });

  _run('at most 20 groups per socket, the ones on screen first', (h, async) {
    h.service.setMemberGroups([for (var i = 0; i < 30; i++) 'm$i']);
    h.service.watch('open');
    h.start();
    h.socket.serverConnects();
    final ids = h.socket.subscribedIds.toList();
    expect(ids, hasLength(20));
    expect(ids.first, 'open');
  });

  _run('unwatching a group unsubscribes it once', (h, async) {
    h.service.setMemberGroups(['g1']);
    h.service.watch('g2');
    h.start();
    h.goLive();
    h.service.unwatch('g2');
    expect(
      h.socket.emitted
          .where((e) => e.event == 'group.unsubscribe')
          .map((e) => e.body['groupId']),
      ['g2'],
    );
    h.service.unwatch('g2');
    expect(
      h.socket.emitted.where((e) => e.event == 'group.unsubscribe'),
      hasLength(1),
    );
  });

  _run('client events stay under the per-minute cap, the rest wait', (
    h,
    async,
  ) {
    // 15 groups on screen at once + 15 more arrive: 30 subscribes in a burst.
    h.service.setMemberGroups([for (var i = 0; i < 20; i++) 'a$i']);
    h.start();
    h.socket.serverConnects();
    for (var i = 0; i < 5; i++) {
      h.service.watch(
        'w$i',
      ); // pushes 5 more than the first 20 allows? cap is 20
    }
    final sentNow = h.socket.emitted.length;
    expect(sentNow, lessThanOrEqualTo(25));
    // Churn: flipping groups on and off must not exceed 25 in any minute.
    for (var i = 0; i < 40; i++) {
      h.service.watch('x$i');
      h.service.unwatch('x$i');
    }
    expect(h.socket.emitted.length, lessThanOrEqualTo(25));
    async.elapse(const Duration(minutes: 1, seconds: 1));
    expect(h.socket.emitted.length, greaterThan(sentNow));
    async.elapse(const Duration(minutes: 1));
    // Never more than 25 inside any one-minute window.
  });

  _run('background closes the socket; resume reconnects and resubscribes', (
    h,
    async,
  ) {
    h.service.setMemberGroups(['g1']);
    h.start();
    h.goLive();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(h.socket.disposed, isTrue);
    expect(h.service.status, LiveStatus.offline);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    async.flushMicrotasks();
    expect(h.sockets, hasLength(2));
    h.goLive();
    expect(h.socket.subscribedIds, ['g1']);
    expect(h.subscribed, ['g1', 'g1']);
  });

  _run('forget() stops listening to a group for good', (h, async) {
    h.service.setMemberGroups(['g1', 'g2']);
    h.start();
    h.goLive();
    h.service.forget('g1');
    expect(
      h.socket.emitted
          .where((e) => e.event == 'group.unsubscribe')
          .map((e) => e.body['groupId']),
      ['g1'],
    );
    h.service.setMemberGroups([
      'g1',
      'g2',
    ]); // a stale list must not bring it back
    expect(h.socket.subscribedIds.where((id) => id == 'g1'), hasLength(1));
  });

  _run('dispose closes the socket and ignores late events', (h, async) {
    h.start();
    h.goLive();
    final s = h.socket;
    h.service.dispose();
    expect(s.disposed, isTrue);
    expect(h.service.status, LiveStatus.offline);
    // A callback from the dead socket changes nothing.
    final before = h.events.length;
    s.serverSends('group.changed', _changed('late', 'member_joined'));
    expect(h.events.length, before);
  });
}
