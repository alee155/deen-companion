import 'package:deen_companion/features/groups/domain/group_invite_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url = 'https://deencompanion.dgexpense.com/invite/tok-1';

  test('names the sender, the group, the app, the link and a way in', () {
    final m = groupInviteMessage(
      senderName: 'Sara Ahmed',
      groupName: 'Family Namaz',
      url: url,
    );
    expect(m, contains('Sara Ahmed has invited you'));
    expect(m, contains('“Family Namaz” on Deen Companion'));
    expect(m, contains('Join now'));
    expect(m, contains(url));
  });

  test('has no app description paragraph', () {
    final m = groupInviteMessage(senderName: 'Sara', groupName: 'G', url: url);
    expect(m, isNot(contains('free app')));
    expect(m, isNot(contains('Quran')));
  });

  test('the link is on its own line so it is tappable in any app', () {
    final m = groupInviteMessage(senderName: 'Sara', groupName: 'G', url: url);
    expect(m.split('\n'), contains(url));
  });

  test('a missing or blank sender name reads as "A friend"', () {
    for (final name in [null, '', '   ']) {
      final m = groupInviteMessage(senderName: name, groupName: 'G', url: url);
      expect(m, contains('A friend has invited you'));
    }
  });

  test('a blank group name does not leave empty quotes', () {
    final m = groupInviteMessage(senderName: 'Sara', groupName: ' ', url: url);
    expect(m, contains('join a prayer group on Deen Companion'));
    expect(m, isNot(contains('“”')));
  });

  test('names are trimmed', () {
    final m = groupInviteMessage(
      senderName: '  Sara  ',
      groupName: '  Family  ',
      url: url,
    );
    expect(m, contains('Sara has invited you'));
    expect(m, contains('“Family”'));
  });

  test('no markdown that other apps would show as stray symbols', () {
    final m = groupInviteMessage(senderName: 'Sara', groupName: 'G', url: url);
    expect(m, isNot(contains('*')));
    expect(m, isNot(contains('_')));
  });
}
