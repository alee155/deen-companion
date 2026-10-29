import 'package:equatable/equatable.dart';

import '../../prayer_times/domain/entities/prayer_times.dart';

/// One stored photo: a signed link to look at it (it expires, so it is read
/// again each time the screen opens) and when it was last set.
class SpecialDayImage extends Equatable {
  final Uri url;
  final DateTime updatedAt;
  const SpecialDayImage({required this.url, required this.updatedAt});

  @override
  List<Object?> get props => [url, updatedAt];
}

/// The special-days state of the signed-in account (`GET /exemption`).
///
/// For female accounts, up to ten days when prayer is exempt: the server logs
/// every prayer window on her behalf, from five photos she uploads first, so
/// her streak and scores carry on. Male or unset accounts are not [eligible].
class SpecialDays extends Equatable {
  final bool eligible;
  final bool active;

  /// When the current period began, and its last local day.
  final DateTime? startedAt;
  final String? startLocalDate;
  final String? endsLocalDate;

  /// The instant the period ends by itself (ten local days at most).
  final DateTime? endsAt;
  final int? daysRemaining;

  /// Which prayers have their photo. The five must be different.
  final Map<PrayerName, bool> images;

  /// Not before this can a new period start (after the last one ended).
  final DateTime? canStartAt;

  /// The server's explanation, shown as it is.
  final String? infoMessage;

  const SpecialDays({
    required this.eligible,
    this.active = false,
    this.startedAt,
    this.startLocalDate,
    this.endsLocalDate,
    this.endsAt,
    this.daysRemaining,
    this.images = const {},
    this.canStartAt,
    this.infoMessage,
  });

  /// What a male or unset account gets: nothing to show.
  static const notEligible = SpecialDays(eligible: false);

  bool hasImage(PrayerName p) => images[p] ?? false;

  /// The prayers still waiting for a photo.
  List<PrayerName> get missingImages => [
    for (final p in PrayerName.values)
      if (!hasImage(p)) p,
  ];

  int get imageCount => PrayerName.values.where(hasImage).length;

  bool get hasAllImages => imageCount == PrayerName.values.length;

  /// Too soon to start again at [now].
  bool isTooSoon(DateTime now) {
    final at = canStartAt;
    return at != null && now.isBefore(at);
  }

  @override
  List<Object?> get props => [
    eligible,
    active,
    startedAt,
    startLocalDate,
    endsLocalDate,
    endsAt,
    daysRemaining,
    images,
    canStartAt,
    infoMessage,
  ];
}
