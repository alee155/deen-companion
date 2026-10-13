/// A group's shareable invite link. [token] is the part after `/invite/`.
class GroupInvite {
  final String token;
  final String url;

  const GroupInvite({required this.token, required this.url});
}
