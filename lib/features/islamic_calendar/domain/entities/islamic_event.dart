import 'hijri_conversion.dart';

class IslamicEvent {
  final int month;
  final int day;
  final String name;
  final String description;

  const IslamicEvent({
    required this.month,
    required this.day,
    required this.name,
    required this.description,
  });
}

class NextIslamicEvent {
  final String name;
  final String hijriDateFormatted;
  final int month;
  final int day;

  const NextIslamicEvent({
    required this.name,
    required this.hijriDateFormatted,
    required this.month,
    required this.day,
  });
}

class IslamicEventsBundle {
  final HijriConversion currentDate;
  final NextIslamicEvent nextEvent;
  final List<IslamicEvent> events;

  const IslamicEventsBundle({
    required this.currentDate,
    required this.nextEvent,
    required this.events,
  });
}
