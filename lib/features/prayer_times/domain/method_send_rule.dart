/// Which calculation method and Asr school to send to the backend.
///
/// The server defaults to Karachi + Hanafi, which suits Pakistan and nowhere
/// else, and it does not guess the country. So the app decides:
/// - the user's own choice is always sent as chosen;
/// - otherwise Pakistan, or an unknown country, sends nothing and the server
///   default applies;
/// - otherwise (a known country outside Pakistan) Muslim World League and
///   Shafi are sent.
/// Routine calls (app open, a movement check) never send either value; the
/// server keeps what is saved.
class MethodSendRule {
  MethodSendRule._();

  static const muslimWorldLeagueId = 3;
  static const shafiId = 0;

  /// The values for the first call, or a guest call. Each is null when it
  /// should be left out of the request.
  static ({int? method, int? school}) resolve({
    int? chosenMethod,
    int? chosenSchool,
    String? countryCode,
  }) {
    final code = countryCode?.trim().toUpperCase();
    final outsidePakistan = code != null && code.isNotEmpty && code != 'PK';
    return (
      method: chosenMethod ?? (outsidePakistan ? muslimWorldLeagueId : null),
      school: chosenSchool ?? (outsidePakistan ? shafiId : null),
    );
  }
}
