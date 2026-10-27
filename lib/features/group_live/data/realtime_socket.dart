import '../../../core/utils/flow_log.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// The slice of a Socket.IO client the app uses, so the service can be tested
/// without a network.
abstract class RealtimeSocket {
  void onConnect(void Function() cb);

  /// [message] is the server's text, e.g. `unauthorized`.
  void onConnectError(void Function(String message) cb);

  /// [reason] is Socket.IO's, e.g. `io server disconnect`.
  void onDisconnect(void Function(String reason) cb);
  void onEvent(String name, void Function(Object? data) cb);
  void emitWithAck(
    String event,
    Map<String, dynamic> body,
    void Function(Object? ack) ack,
  );
  void connect();

  /// Closes the connection without reconnecting.
  void disconnect();
  void dispose();
}

/// Creates a socket for [url]. The token is asked for on every (re)connect, so
/// a reconnect never sends a stale one.
typedef RealtimeSocketFactory =
    RealtimeSocket Function(String url, Future<String?> Function() token);

RealtimeSocket createSocketIoRealtimeSocket(
  String url,
  Future<String?> Function() token,
) => SocketIoRealtimeSocket(url, token);

class SocketIoRealtimeSocket implements RealtimeSocket {
  final io.Socket _socket;

  SocketIoRealtimeSocket(String url, Future<String?> Function() token)
    : _socket = io.io(
        url,
        io.OptionBuilder()
            // WebSocket only. On Android/iOS socket_io_client has no HTTP
            // long-polling transport (its source: "Native only supports
            // websocket"): asking for 'polling' still opens a WebSocket, but
            // labelled transport=polling, which the server then refuses.
            .setTransports(['websocket'])
            // In the handshake `auth` object only: a token in the URL is
            // refused by the server.
            .setAuthFn((callback) async {
              callback({'token': await token() ?? ''});
            })
            .disableAutoConnect()
            .enableForceNew()
            // The library retries transport failures with backoff; a refused
            // handshake (`unauthorized`) and a server-side drop are not
            // retried by it, so neither can loop.
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(30000)
            .setRandomizationFactor(0.5)
            .build(),
      );

  @override
  void onConnect(void Function() cb) => _socket.onConnect((_) => cb());

  @override
  void onConnectError(void Function(String message) cb) =>
      _socket.onConnectError((e) => cb(_message(e)));

  @override
  void onDisconnect(void Function(String reason) cb) =>
      _socket.onDisconnect((r) => cb('$r'));

  @override
  void onEvent(String name, void Function(Object? data) cb) =>
      _socket.on(name, cb);

  @override
  void emitWithAck(
    String event,
    Map<String, dynamic> body,
    void Function(Object? ack) ack,
  ) => _socket.emitWithAck(event, body, ack: (arg, [_]) => ack(arg));

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  void dispose() => _socket.dispose();

  /// A refused handshake arrives as `{message: 'unauthorized'}` (or a bare
  /// string); transport failures as an error object.
  static String _message(Object? e) {
    FlowLog.log('REALTIME', 'RAW CONNECT ERROR (${e.runtimeType}): $e');
    if (e is Map && e['message'] is String) return e['message'] as String;
    return '$e';
  }
}
