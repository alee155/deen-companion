/// The text a member copies or shares to invite someone to a group: who is
/// inviting, what the app is, the link, and a clear way in.
///
/// Plain text with a few emoji, so it reads the same in WhatsApp, SMS, email
/// and anywhere else it lands (no markdown, which other apps would show as
/// stray asterisks).
String groupInviteMessage({
  required String? senderName,
  required String groupName,
  required String url,
}) {
  final sender = (senderName ?? '').trim();
  final who = sender.isEmpty ? 'A friend' : sender;
  final group = groupName.trim();
  final which = group.isEmpty ? 'a prayer group' : '“$group”';

  return 'Assalamu Alaikum! 🌙\n'
      '\n'
      '$who has invited you to join $which on Deen Companion.\n'
      '\n'
      'Deen Companion is a free app for your daily worship: accurate prayer '
      'times and Qibla, the Quran, Hadith and Duas, plus private prayer '
      'groups where family and friends encourage each other, share prayer '
      'snaps and build streaks together. 🤲\n'
      '\n'
      '👉 Join now:\n'
      '$url\n'
      '\n'
      'Tap the link to join the group. May Allah make it easy for us all. 🤍';
}
