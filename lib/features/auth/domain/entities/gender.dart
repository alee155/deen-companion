/// The two values the backend accepts. It is chosen once, at sign-up (or, for
/// accounts made before the field existed, through a one-time prompt) and can
/// never be changed afterwards.
enum Gender {
  male('male', 'Male'),
  female('female', 'Female');

  /// What goes over the wire.
  final String wire;
  final String label;
  const Gender(this.wire, this.label);

  /// Null for a missing or unknown value ("not set yet").
  static Gender? parse(Object? raw) {
    for (final g in values) {
      if (g.wire == raw) return g;
    }
    return null;
  }
}
