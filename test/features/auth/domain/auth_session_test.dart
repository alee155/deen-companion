import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSession', () {
    test('guest is not authenticated', () {
      const s = AuthSession.guest();
      expect(s.isGuest, isTrue);
      expect(s.isAuthenticated, isFalse);
    });

    test('non-guest without userId is not authenticated', () {
      expect(const AuthSession(email: 'a@b.c').isAuthenticated, isFalse);
    });

    test('guest with userId is still not authenticated', () {
      expect(
        const AuthSession(userId: '1', isGuest: true).isAuthenticated,
        isFalse,
      );
    });

    test('user with id is authenticated', () {
      expect(const AuthSession(userId: '1').isAuthenticated, isTrue);
    });

    group('displayName', () {
      test('prefers trimmed name', () {
        expect(
          const AuthSession(name: '  Ali  ', email: 'x@y.z').displayName,
          'Ali',
        );
      });

      test('falls back to email local part when name blank', () {
        expect(
          const AuthSession(name: '   ', email: 'ali.k@mail.com').displayName,
          'ali.k',
        );
      });

      test('falls back to Friend when nothing usable', () {
        expect(const AuthSession().displayName, 'Friend');
        expect(const AuthSession(email: 'no-at-sign').displayName, 'Friend');
        expect(const AuthSession.guest().displayName, 'Friend');
      });
    });

    group('initials', () {
      test('two words give two uppercase letters', () {
        expect(const AuthSession(name: 'muhammad ali').initials, 'MA');
      });

      test('only first two words are used', () {
        expect(const AuthSession(name: 'a b c d').initials, 'AB');
      });

      test('single word gives one letter', () {
        expect(const AuthSession(name: 'omar').initials, 'O');
      });

      test('handles extra whitespace', () {
        expect(const AuthSession(name: '  zaid    bin  ').initials, 'ZB');
      });

      test('uses email local part when no name', () {
        expect(const AuthSession(email: 'sara@x.com').initials, 'S');
      });

      test('guest initial derives from Friend', () {
        expect(const AuthSession.guest().initials, 'F');
      });
    });
  });
}
