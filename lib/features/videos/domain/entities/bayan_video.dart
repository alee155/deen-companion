import 'package:equatable/equatable.dart';

import 'video_source.dart';

/// One talk (bayan) from the daily set.
class BayanVideo extends Equatable {
  final String id;
  final String title;
  final String speaker;
  final String? description;
  final String category;
  final String language;

  /// Null when the API doesn't know it (it often doesn't).
  final Duration? duration;
  final VideoSource source;

  /// A picture for the video: the API's, or the platform's own for this id.
  final Uri? thumbnail;

  const BayanVideo({
    required this.id,
    required this.title,
    required this.speaker,
    required this.category,
    required this.language,
    required this.source,
    this.description,
    this.duration,
    this.thumbnail,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    speaker,
    description,
    category,
    language,
    duration,
    source,
    thumbnail,
  ];
}
