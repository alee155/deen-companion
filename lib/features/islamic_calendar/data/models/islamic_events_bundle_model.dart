import '../../domain/entities/islamic_event.dart';
import 'hijri_conversion_model.dart';

class IslamicEventModel {
  final int month;
  final int day;
  final String name;
  final String description;

  const IslamicEventModel({
    required this.month,
    required this.day,
    required this.name,
    required this.description,
  });

  factory IslamicEventModel.fromJson(Map<String, dynamic> json) {
    return IslamicEventModel(
      month: json['month'] as int,
      day: json['day'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'month': month,
    'day': day,
    'name': name,
    'description': description,
  };

  IslamicEvent toEntity() => IslamicEvent(
    month: month,
    day: day,
    name: name,
    description: description,
  );
}

class NextIslamicEventModel {
  final String name;
  final String hijriDateFormatted;
  final int month;
  final int day;

  const NextIslamicEventModel({
    required this.name,
    required this.hijriDateFormatted,
    required this.month,
    required this.day,
  });

  factory NextIslamicEventModel.fromJson(Map<String, dynamic> json) {
    return NextIslamicEventModel(
      name: json['name'] as String,
      hijriDateFormatted: json['hijri_date'] as String,
      month: json['month'] as int,
      day: json['day'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'hijri_date': hijriDateFormatted,
    'month': month,
    'day': day,
  };

  NextIslamicEvent toEntity() => NextIslamicEvent(
    name: name,
    hijriDateFormatted: hijriDateFormatted,
    month: month,
    day: day,
  );
}

class IslamicEventsBundleModel {
  final HijriConversionModel currentDate;
  final NextIslamicEventModel nextEvent;
  final List<IslamicEventModel> events;

  const IslamicEventsBundleModel({
    required this.currentDate,
    required this.nextEvent,
    required this.events,
  });

  factory IslamicEventsBundleModel.fromJson(Map<String, dynamic> json) {
    return IslamicEventsBundleModel(
      currentDate: HijriConversionModel.fromJson(
        json['current_hijri_date'] as Map<String, dynamic>,
      ),
      nextEvent: NextIslamicEventModel.fromJson(
        json['next_event'] as Map<String, dynamic>,
      ),
      events: (json['events'] as List)
          .map((e) => IslamicEventModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'current_hijri_date': currentDate.toJson(),
    'next_event': nextEvent.toJson(),
    'events': events.map((e) => e.toJson()).toList(),
  };
}
