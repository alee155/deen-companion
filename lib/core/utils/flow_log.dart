import 'package:flutter/foundation.dart';

import '../config/flavor_config.dart';

/// Step-by-step trace of the app's flows, for reading in the terminal.
///
/// Every line is wrapped in `**********` on both sides and carries a `[TAG]`
/// for the part of the app it comes from, so one search for `**********`
/// shows the whole story and `**********.*\[PRAYER TIMES\]` narrows it to one
/// flow:
///
/// ```
/// ********** [PRAYER TIMES] REFRESH STARTED **********
/// ********** [API #3] REQUEST STARTED  GET /prayers/times **********
/// ```
///
/// Printed only in debug builds of the dev flavor (`enableLogging`). Values go
/// through [redact] first, so passwords, OTPs, tokens and e-mail addresses
/// never reach the terminal, and a signed photo link shows where the image is
/// without its signature (see [describeSignedUrl]).
class FlowLog {
  FlowLog._();

  static const marker = '**********';

  /// `debugPrint` breaks lines longer than this, and a broken line would lose
  /// its markers — so long messages are split here instead.
  static const _chunk = 700;

  /// Test hooks: force logging on or off, and capture what is printed.
  @visibleForTesting
  static bool? enabledOverride;
  @visibleForTesting
  static void Function(String line)? sink;

  static bool get enabled {
    final forced = enabledOverride;
    if (forced != null) return forced;
    if (!kDebugMode) return false;
    try {
      return FlavorConfig.instance.enableLogging;
    } catch (_) {
      return false; // flavor not set up (e.g. in a unit test)
    }
  }

  static int _apiCounter = 0;

  /// A number to tie one request to its response: `[API #7]`.
  static int nextApiId() => ++_apiCounter;

  /// `********** [TAG] message **********`
  static void log(String tag, String message) {
    if (!enabled) return;
    _emit('[$tag] $message');
  }

  /// `********** [TAG] label: value **********` — [value] is redacted and
  /// shortened first.
  static void data(String tag, String label, Object? value) {
    if (!enabled) return;
    _emit('[$tag] $label: ${summarize(value)}');
  }

  /// `********** [TAG] ERROR: message — details **********`
  static void error(String tag, String message, [Object? details]) {
    if (!enabled) return;
    final extra = details == null ? '' : ' — ${summarize(details)}';
    _emit('[$tag] ERROR: $message$extra');
  }

  static void _emit(String text) {
    final print = sink ?? debugPrint;
    for (final line in text.split('\n')) {
      if (line.length <= _chunk) {
        print('$marker $line $marker');
        continue;
      }
      for (var i = 0; i < line.length; i += _chunk) {
        final end = i + _chunk < line.length ? i + _chunk : line.length;
        print('$marker ${line.substring(i, end)} $marker');
      }
    }
  }

  // ── Redaction and summaries ─────────────────────────────────────────────

  /// Keys whose values are never printed, compared lower-case without
  /// punctuation (`access_token`, `accessToken` and `Access-Token` match).
  static const _secret = {
    'password',
    'newpassword',
    'oldpassword',
    'currentpassword',
    'otp',
    'token',
    'accesstoken',
    'refreshtoken',
    'authorization',
    'apikey',
    'xapikey',
  };

  /// Printed shortened rather than hidden: still useful to tell two apart.
  static const _masked = {'email', 'xdeviceid'};

  static String _normalize(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  /// A copy of [value] that is safe to print.
  static Object? redact(Object? value) {
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key: _redactEntry(e.key.toString(), e.value),
      };
    }
    if (value is List) return [for (final v in value) redact(v)];
    return value;
  }

  static Object? _redactEntry(String key, Object? value) {
    final k = _normalize(key);
    if (k == 'snapurl') {
      return value is String ? describeSignedUrl(value) : value;
    }
    if (_secret.contains(k)) return value == null ? null : '***';
    if (_masked.contains(k)) return value is String ? mask(value) : value;
    return redact(value);
  }

  /// A private photo's signed link, safe to print: where the image lives, but
  /// not the signature that unlocks it. The query string is dropped and a
  /// Cloudinary `s--…--` signature segment is blanked, so the line shows that a
  /// photo came back (and which one) without being a working link.
  static String describeSignedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return '***';
    final path = uri.path.replaceAll(RegExp(r's--[^/]*--'), 's--***--');
    return '${uri.scheme}://${uri.host}$path (signed link, signature hidden)';
  }

  /// `1f3a9b2c-…` / `a***@gmail.com`: enough to recognise, not to use.
  static String mask(String value) {
    final at = value.indexOf('@');
    if (at > 0) return '${value[0]}***${value.substring(at)}';
    if (value.length <= 8) return '***';
    return '${value.substring(0, 8)}…';
  }

  /// A short, redacted, human-readable form: long lists show their first two
  /// items and a count, long strings are cut.
  static String summarize(Object? value, {int maxDepth = 5}) =>
      _summarize(redact(value), maxDepth);

  static String _summarize(Object? v, int depth) {
    if (v == null) return 'null';
    if (v is String) {
      return v.length > 160
          ? '${v.substring(0, 160)}… (+${v.length - 160})'
          : v;
    }
    if (v is num || v is bool) return '$v';
    if (depth <= 0) return '…';
    if (v is Map) {
      final parts = [
        for (final e in v.entries)
          '${e.key}: ${_summarize(e.value, depth - 1)}',
      ];
      return '{${parts.join(', ')}}';
    }
    if (v is List) {
      final shown = v.take(2).map((e) => _summarize(e, depth - 1)).join(', ');
      final more = v.length > 2 ? ', … +${v.length - 2} more' : '';
      return '[$shown$more]';
    }
    return v.toString();
  }
}
