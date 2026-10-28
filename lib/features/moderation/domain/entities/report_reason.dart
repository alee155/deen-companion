/// Why someone is being reported. The set is deliberately short: a person in
/// the moment picks one, and anything else goes in "Something else" with a
/// note. The values are what the API will receive, so they are stable names,
/// not display text.
enum ReportReason {
  inappropriate,
  harassment,
  spam,
  impersonation,
  other;

  /// The value sent to the server.
  String get apiValue => name;
}
