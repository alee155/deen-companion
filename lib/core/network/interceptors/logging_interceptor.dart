import 'package:dio/dio.dart';

import '../../utils/flow_log.dart';

/// Traces every HTTP call in the terminal (dev flavor only), tied together by
/// an id so a request and its response can be matched:
///
/// ```
/// ********** [API #3] REQUEST STARTED  GET /api/prayers/times **********
/// ********** [API #3] request query: {days: 31} **********
/// ********** [API #3] RESPONSE RECEIVED  status 200  (142 ms) **********
/// ```
///
/// Bodies, queries and headers are redacted by [FlowLog]: passwords, OTPs,
/// tokens (the auth header shows only whether one was sent), e-mail
/// addresses and signed photo links never appear, and photo bytes are never
/// printed — only the file's name, size and type.
class LoggingInterceptor extends Interceptor {
  static const _idKey = 'flowLogId';
  static const _startKey = 'flowLogStart';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (FlowLog.enabled) {
      final id = FlowLog.nextApiId();
      options.extra[_idKey] = id;
      options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
      final tag = 'API #$id';

      FlowLog.log(tag, 'REQUEST STARTED  ${options.method} ${_where(options)}');
      if (options.queryParameters.isNotEmpty) {
        FlowLog.data(tag, 'request query', options.queryParameters);
      }
      final body = _describeBody(options.data);
      if (body != null) FlowLog.data(tag, 'request body', body);
      FlowLog.data(tag, 'request headers', _headersOf(options));
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (FlowLog.enabled) {
      final tag = _tag(response.requestOptions);
      FlowLog.log(
        tag,
        'RESPONSE RECEIVED  status ${response.statusCode}'
        '${_elapsed(response.requestOptions)}',
      );
      FlowLog.data(tag, 'response body', response.data);
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (FlowLog.enabled) {
      final tag = _tag(err.requestOptions);
      final status = err.response?.statusCode;
      FlowLog.log(
        tag,
        'REQUEST FAILED  '
        '${status != null ? 'status $status' : 'no response'}'
        ' (${err.type.name})${_elapsed(err.requestOptions)}',
      );
      if (err.response?.data != null) {
        FlowLog.data(tag, 'error body', err.response!.data);
      }
      if (err.message != null) FlowLog.data(tag, 'error message', err.message);
    }
    super.onError(err, handler);
  }

  static String _tag(RequestOptions o) => 'API #${o.extra[_idKey] ?? '?'}';

  /// `/api/prayers/times`, with the host when it is not the Deen backend.
  static String _where(RequestOptions o) {
    final uri = o.uri;
    return uri.host.contains('dgexpense.com')
        ? uri.path
        : '${uri.host}${uri.path}';
  }

  static String _elapsed(RequestOptions o) {
    final start = o.extra[_startKey];
    if (start is! int) return '';
    return '  (${DateTime.now().millisecondsSinceEpoch - start} ms)';
  }

  /// Photo uploads are described, never dumped.
  static Object? _describeBody(Object? data) {
    if (data == null) return null;
    if (data is FormData) {
      return {
        for (final f in data.fields) f.key: f.value,
        for (final f in data.files)
          f.key:
              'file ${f.value.filename} · ${f.value.length} bytes · '
              '${f.value.contentType}',
      };
    }
    return data;
  }

  /// Only what helps follow the flow. The token itself is never shown, only
  /// whether one was sent. (Keyed `Auth`, not `Authorization`, because
  /// [FlowLog] hides the value of anything named like a credential.)
  static Map<String, Object?> _headersOf(RequestOptions o) {
    final auth = o.headers['Authorization'];
    return {
      'Auth': auth == null ? 'none' : 'Bearer ***',
      if (o.headers['X-Device-Id'] != null)
        'X-Device-Id': FlowLog.mask('${o.headers['X-Device-Id']}'),
    };
  }
}
