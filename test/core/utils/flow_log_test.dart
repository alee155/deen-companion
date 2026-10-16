import 'package:deen_companion/core/utils/flow_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> lines;

  setUp(() {
    lines = [];
    FlowLog.enabledOverride = true;
    FlowLog.sink = lines.add;
  });

  tearDown(() {
    FlowLog.enabledOverride = null;
    FlowLog.sink = null;
  });

  test('every line starts and ends with the marker', () {
    FlowLog.log('PRAYER TIMES', 'REFRESH STARTED');
    FlowLog.data('API #1', 'request query', {'days': 31});
    FlowLog.error('API #1', 'REQUEST FAILED', 'boom');
    expect(lines, hasLength(3));
    for (final l in lines) {
      expect(l, startsWith('********** '));
      expect(l, endsWith(' **********'));
    }
  });

  test('log, data and error formats', () {
    FlowLog.log('PRAYER TIMES', 'REFRESH STARTED');
    FlowLog.data('API #1', 'request query', {'days': 31});
    FlowLog.error('API #1', 'REQUEST FAILED', 'boom');
    expect(lines[0], '********** [PRAYER TIMES] REFRESH STARTED **********');
    expect(
      lines[1],
      '********** [API #1] request query: {days: 31} **********',
    );
    expect(
      lines[2],
      '********** [API #1] ERROR: REQUEST FAILED — boom **********',
    );
  });

  test('prints nothing when disabled', () {
    FlowLog.enabledOverride = false;
    FlowLog.log('X', 'y');
    FlowLog.data('X', 'y', 1);
    FlowLog.error('X', 'y');
    expect(lines, isEmpty);
  });

  test('is off by default when the flavor is not set up', () {
    FlowLog.enabledOverride = null;
    FlowLog.log('X', 'y');
    expect(lines, isEmpty);
  });

  group('multi-line and long messages keep their markers', () {
    test('each line of a multi-line message is wrapped', () {
      FlowLog.log('X', 'one\ntwo');
      expect(lines, [
        '********** [X] one **********',
        '********** two **********',
      ]);
    });

    test('a very long line is split, every piece wrapped', () {
      FlowLog.log('X', 'a' * 2000);
      expect(lines.length, greaterThan(2));
      for (final l in lines) {
        expect(l.startsWith('********** '), isTrue);
        expect(l.endsWith(' **********'), isTrue);
        expect(l.length, lessThanOrEqualTo(700 + 24));
      }
    });
  });

  group('secrets never reach the terminal', () {
    test('passwords, OTPs and tokens are hidden', () {
      FlowLog.data('API #2', 'body', {
        'email': 'ali@example.com',
        'password': 'hunter2-secret',
        'newPassword': 'brand-new-secret',
        'otp': '4821',
        'accessToken': 'eyJhbGciOi.payload.sig',
        'token': 'abc',
        'Authorization': 'Bearer eyJhbGciOi.payload.sig',
        'apiKey': 'key-123',
      });
      final out = lines.join('\n');
      for (final secret in [
        'hunter2-secret',
        'brand-new-secret',
        '4821',
        'eyJhbGciOi',
        'Bearer',
        'key-123',
        'ali@example.com',
      ]) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
      expect(out, contains('password: ***'));
      expect(out, contains('otp: ***'));
    });

    test('key matching ignores case and punctuation', () {
      final shown = FlowLog.summarize({
        'access_token': 'x1',
        'Access-Token': 'x2',
        'PASSWORD': 'x3',
        'x-api-key': 'x4',
      });
      for (final v in ['x1', 'x2', 'x3', 'x4']) {
        expect(shown, isNot(contains(v)));
      }
    });

    test('secrets nested in lists and maps are hidden', () {
      final shown = FlowLog.summarize({
        'users': [
          {'name': 'Ali', 'password': 'pw-1'},
        ],
      });
      expect(shown, contains('Ali'));
      expect(shown, isNot(contains('pw-1')));
    });

    test('a signed photo link shows where it is, not how to open it', () {
      final shown = FlowLog.summarize({
        'snapUrl':
            'https://res.cloudinary.com/demo/image/authenticated/'
            's--AbCdEf12--/v1700000000/prayers/abc123.jpg?token=SECRETQUERY',
      });
      expect(shown, contains('res.cloudinary.com'));
      expect(shown, contains('prayers/abc123.jpg'));
      expect(shown, contains('s--***--'));
      expect(shown, isNot(contains('AbCdEf12')), reason: 'path signature');
      expect(shown, isNot(contains('SECRETQUERY')), reason: 'query');
      expect(shown, isNot(contains('token=')));
      expect(shown, contains('signature hidden'));
    });

    test('a photo link with only a query signature loses the query', () {
      final shown = FlowLog.summarize({
        'snapUrl': 'https://img.test/a/b.jpg?sig=TOPSECRET&exp=123',
      });
      expect(shown, contains('img.test/a/b.jpg'));
      expect(shown, isNot(contains('TOPSECRET')));
      expect(shown, isNot(contains('exp=')));
    });

    test('a photo link that is not a URL is hidden entirely', () {
      expect(FlowLog.summarize({'snapUrl': 'not a url'}), '{snapUrl: ***}');
    });

    test('describeSignedUrl is usable on its own', () {
      expect(
        FlowLog.describeSignedUrl('https://x.test/s--abc--/p.jpg?z=1'),
        'https://x.test/s--***--/p.jpg (signed link, signature hidden)',
      );
    });

    test('a missing secret stays null rather than showing ***', () {
      expect(FlowLog.summarize({'snapUrl': null}), '{snapUrl: null}');
    });

    test('e-mail and device id are shortened, not shown in full', () {
      expect(FlowLog.mask('ali@example.com'), 'a***@example.com');
      expect(FlowLog.mask('1f3a9b2c-aaaa-4bbb-8ccc-123456789012'), '1f3a9b2c…');
      expect(FlowLog.mask('short'), '***');
    });

    test('redact does not change the original', () {
      final original = {'password': 'keep-me'};
      FlowLog.redact(original);
      expect(original['password'], 'keep-me');
    });
  });

  group('summaries stay readable', () {
    test('a long list shows two items and a count', () {
      final shown = FlowLog.summarize({
        'days': List.generate(31, (i) => {'date': 'd$i'}),
      });
      expect(shown, contains('d0'));
      expect(shown, contains('d1'));
      expect(shown, contains('+29 more'));
      expect(shown, isNot(contains('d30')));
    });

    test('long strings are cut', () {
      final shown = FlowLog.summarize('z' * 500);
      expect(shown.length, lessThan(220));
      expect(shown, contains('+340'));
    });

    test('nesting depth is limited', () {
      final shown = FlowLog.summarize({
        'a': {
          'b': {
            'c': {
              'd': {
                'e': {'f': 1},
              },
            },
          },
        },
      });
      expect(shown, contains('…'));
    });

    test('null, numbers and booleans print plainly', () {
      expect(FlowLog.summarize(null), 'null');
      expect(FlowLog.summarize(31.5), '31.5');
      expect(FlowLog.summarize(true), 'true');
    });
  });

  test('API ids count up', () {
    final a = FlowLog.nextApiId();
    final b = FlowLog.nextApiId();
    expect(b, a + 1);
  });
}
