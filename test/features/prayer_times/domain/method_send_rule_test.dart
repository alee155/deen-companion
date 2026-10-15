import 'package:deen_companion/features/prayer_times/domain/method_send_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pakistan or unknown country: nothing is sent', () {
    for (final country in ['PK', 'pk', ' PK ', null, '']) {
      test('country "$country"', () {
        final r = MethodSendRule.resolve(countryCode: country);
        expect(r.method, isNull);
        expect(r.school, isNull);
      });
    }
  });

  test('a known country outside Pakistan sends MWL (3) and Shafi (0)', () {
    for (final country in ['AE', 'gb', 'US']) {
      final r = MethodSendRule.resolve(countryCode: country);
      expect(r.method, 3, reason: country);
      expect(r.school, 0, reason: country);
    }
  });

  test('the user\'s choice is always sent exactly as chosen', () {
    final r = MethodSendRule.resolve(
      chosenMethod: 5,
      chosenSchool: 1,
      countryCode: 'PK',
    );
    expect(r.method, 5);
    expect(r.school, 1);
  });

  test('each setting is decided on its own', () {
    // Chose only Hanafi, outside Pakistan: the method still follows the rule.
    final abroad = MethodSendRule.resolve(chosenSchool: 1, countryCode: 'AE');
    expect(abroad.method, 3);
    expect(abroad.school, 1);

    // Chose only a method, in Pakistan: the school is left to the server.
    final home = MethodSendRule.resolve(chosenMethod: 3, countryCode: 'PK');
    expect(home.method, 3);
    expect(home.school, isNull);
  });
}
