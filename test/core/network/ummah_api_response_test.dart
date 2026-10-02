import 'package:deen_companion/core/network/ummah_api_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unwraps envelope and parses data', () {
    final r = UmmahApiResponse<int>.fromJson({
      'success': true,
      'service': 'quran',
      'data': {'n': 7},
      'timestamp': 'x',
    }, (d) => d['n'] as int);
    expect(r.success, isTrue);
    expect(r.service, 'quran');
    expect(r.data, 7);
  });

  test('missing success/service default to false/empty', () {
    final r = UmmahApiResponse<String>.fromJson({
      'data': <String, dynamic>{'a': 'b'},
    }, (d) => d['a'] as String);
    expect(r.success, isFalse);
    expect(r.service, '');
    expect(r.data, 'b');
  });

  test('missing data throws (callers must catch)', () {
    expect(
      () => UmmahApiResponse<int>.fromJson({'success': true}, (_) => 1),
      throwsA(isA<TypeError>()),
    );
  });

  test('data of wrong type throws', () {
    expect(
      () => UmmahApiResponse<int>.fromJson({
        'success': true,
        'data': [1, 2],
      }, (_) => 1),
      throwsA(isA<TypeError>()),
    );
  });

  test('parser exceptions propagate', () {
    expect(
      () => UmmahApiResponse<int>.fromJson({
        'data': <String, dynamic>{},
      }, (d) => d['missing'] as int),
      throwsA(isA<TypeError>()),
    );
  });
}
