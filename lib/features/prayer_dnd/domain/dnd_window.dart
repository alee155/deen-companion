/// One planned Do Not Disturb window, as the native side expects it.
class DndWindow {
  final String prayerName;
  final DateTime start;
  final DateTime end;

  const DndWindow({
    required this.prayerName,
    required this.start,
    required this.end,
  });

  Map<String, Object?> toMap() => {
    'prayerName': prayerName,
    'startMillis': start.millisecondsSinceEpoch,
    'endMillis': end.millisecondsSinceEpoch,
  };
}
