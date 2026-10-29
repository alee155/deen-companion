import '../../domain/entities/bayan_video.dart';
import '../../domain/entities/daily_videos.dart';
import '../../domain/services/video_platform_registry.dart';

/// `data` of `GET /videos/random`:
///
/// ```
/// {date, validUntil, count, videos: [
///   {id, videoId, title, speaker, description, category, language,
///    durationSeconds, url, thumbnailUrl}]}
/// ```
///
/// There is no platform field: it is worked out from `url` by [registry], so
/// a link from another platform needs no change here. One bad entry (no title,
/// or a link that isn't a web address) is skipped, never the whole day.
DailyVideos dailyVideosFromJson(
  Map<String, dynamic> json,
  VideoPlatformRegistry registry,
) {
  final videos = <BayanVideo>[];
  for (final raw in (json['videos'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final video = _videoFromJson(Map<String, dynamic>.from(raw), registry);
    if (video != null) videos.add(video);
  }
  return DailyVideos(
    date: json['date'] as String? ?? '',
    validUntil: DateTime.parse(json['validUntil'] as String).toUtc(),
    videos: videos,
  );
}

BayanVideo? _videoFromJson(
  Map<String, dynamic> json,
  VideoPlatformRegistry registry,
) {
  String? text(Object? v) {
    final s = v is String ? v.trim() : null;
    return s == null || s.isEmpty ? null : s;
  }

  Uri? web(Object? v) {
    final s = text(v);
    final uri = s == null ? null : Uri.tryParse(s);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? uri
        : null;
  }

  final id = text(json['id']);
  final title = text(json['title']);
  final url = web(json['url']);
  if (id == null || title == null || url == null) return null;

  final source = registry.resolve(url, idHint: text(json['videoId']));
  final seconds = (json['durationSeconds'] as num?)?.toInt();

  return BayanVideo(
    id: id,
    title: title,
    speaker: text(json['speaker']) ?? '',
    description: text(json['description']),
    category: text(json['category']) ?? '',
    language: text(json['language']) ?? '',
    duration: seconds == null || seconds <= 0
        ? null
        : Duration(seconds: seconds),
    source: source,
    // The API's picture, else the platform's own for this video.
    thumbnail: web(json['thumbnailUrl']) ?? registry.thumbnailFor(source),
  );
}

/// The same shape back, for the saved copy.
Map<String, dynamic> dailyVideosToJson(DailyVideos d) => {
  'date': d.date,
  'validUntil': d.validUntil.toUtc().toIso8601String(),
  'count': d.videos.length,
  'videos': [
    for (final v in d.videos)
      {
        'id': v.id,
        'videoId': v.source.videoId,
        'title': v.title,
        'speaker': v.speaker,
        'description': v.description,
        'category': v.category,
        'language': v.language,
        'durationSeconds': v.duration?.inSeconds,
        'url': v.source.uri.toString(),
        'thumbnailUrl': v.thumbnail?.toString(),
      },
  ],
};
