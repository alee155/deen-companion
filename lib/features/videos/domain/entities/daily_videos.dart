import 'package:equatable/equatable.dart';

import 'bayan_video.dart';

/// The set of videos for one local day (`GET /videos/random`). It is the same
/// for everyone until [validUntil], when the next day's set replaces it.
class DailyVideos extends Equatable {
  /// The local date (`yyyy-MM-dd`) the set belongs to.
  final String date;

  /// The instant the set changes (midnight, in the server's day zone).
  final DateTime validUntil;
  final List<BayanVideo> videos;

  const DailyVideos({
    required this.date,
    required this.validUntil,
    required this.videos,
  });

  bool isValidAt(DateTime now) => now.toUtc().isBefore(validUntil.toUtc());

  /// Categories in order of first appearance, for the filter chips.
  List<String> get categories => <String>{
    for (final v in videos)
      if (v.category.isNotEmpty) v.category,
  }.toList();

  BayanVideo? byId(String id) {
    for (final v in videos) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  List<Object?> get props => [date, validUntil, videos];
}
