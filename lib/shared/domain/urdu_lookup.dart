/// Where a saved row's Urdu stands: not wanted (English chosen, or not that
/// kind of row), still being read, found, or confirmed missing.
enum UrduState { notUrdu, loading, found, missing }

class UrduLookup {
  final UrduState state;
  final String text;

  const UrduLookup._(this.state, this.text);

  static const notUrdu = UrduLookup._(UrduState.notUrdu, '');
  static const loading = UrduLookup._(UrduState.loading, '');
  static const missing = UrduLookup._(UrduState.missing, '');
  const UrduLookup.found(String text) : this._(UrduState.found, text);

  /// Found text, or [missing] when it is empty.
  factory UrduLookup.of(String? text) {
    final t = text?.trim() ?? '';
    return t.isEmpty ? missing : UrduLookup.found(t);
  }
}
