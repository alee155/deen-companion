import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/videos/data/models/daily_videos_model.dart';
import 'package:deen_companion/features/videos/domain/entities/bayan_video.dart';
import 'package:deen_companion/features/videos/domain/entities/daily_videos.dart';
import 'package:deen_companion/features/videos/domain/repositories/videos_repository.dart';
import 'package:deen_companion/features/videos/domain/services/video_platform_registry.dart';

/// Taken from the live `GET /videos/random` response (three of its nine).
Map<String, dynamic> sampleDay({
  String validUntil = '2026-10-29T19:00:00.000Z',
  List<Map<String, dynamic>>? videos,
}) => {
  'date': '2026-10-29',
  'validUntil': validUntil,
  'count': 3,
  'videos':
      videos ??
      [
        {
          'id': '68de0e4c-d381-11f1-a6bb-005056010280',
          'videoId': '5ES0cFPNpbE',
          'title': 'The Love of Allah | Life Changing Bayan',
          'speaker': 'Maulana Tariq Jameel',
          'description': 'Allah ki mohabbat par bayan (Feb 2025)',
          'category': 'Allah ki Mohabbat',
          'language': 'Urdu',
          'durationSeconds': null,
          'url': 'https://www.youtube.com/watch?v=5ES0cFPNpbE',
          'thumbnailUrl':
              'https://img.youtube.com/vi/5ES0cFPNpbE/hqdefault.jpg',
        },
        {
          'id': '68e2a1b6-d381-11f1-a6bb-005056010280',
          'videoId': 'Uq5YCuGkgjo',
          'title': 'Namaz Importance | Way To Jannah',
          'speaker': 'Engineer Muhammad Ali Mirza',
          'description': 'Namaz ki ahmiyat aur namaz chhorne ka anjam',
          'category': 'Namaz',
          'language': 'Urdu',
          'durationSeconds': null,
          'url': 'https://www.youtube.com/watch?v=Uq5YCuGkgjo',
          'thumbnailUrl':
              'https://img.youtube.com/vi/Uq5YCuGkgjo/hqdefault.jpg',
        },
        {
          'id': '68e3975b-d381-11f1-a6bb-005056010280',
          'videoId': 'rsb3X6A8q_o',
          'title': 'Complete Practical of Namaz-e-Muhammadi',
          'speaker': 'Engineer Muhammad Ali Mirza',
          'description': "Namaz ka amali tareeqa (clip, 70-a-Mas'alah)",
          'category': 'Namaz',
          'language': 'Urdu',
          'durationSeconds': null,
          'url': 'https://www.youtube.com/watch?v=rsb3X6A8q_o',
          'thumbnailUrl':
              'https://img.youtube.com/vi/rsb3X6A8q_o/hqdefault.jpg',
        },
      ],
};

const registry = VideoPlatformRegistry();

DailyVideos sampleDaily({String validUntil = '2099-01-01T00:00:00.000Z'}) =>
    dailyVideosFromJson(sampleDay(validUntil: validUntil), registry);

BayanVideo videoAt(int i, {DailyVideos? from}) =>
    (from ?? sampleDaily()).videos[i];

class FakeVideosRepo implements VideosRepository {
  DailyVideos? cached;
  Result<DailyVideos> result;
  int calls = 0;
  FakeVideosRepo({this.cached, Result<DailyVideos>? result})
    : result = result ?? Success(sampleDaily());

  @override
  DailyVideos? getCached() => cached;

  @override
  Future<Result<DailyVideos>> getDailyVideos({
    bool forceRefresh = false,
  }) async {
    calls++;
    return result;
  }
}

/// [n] YouTube talks titled "Talk 0", "Talk 1", ...
DailyVideos dailyVideosFromMany(int n) => dailyVideosFromJson(
  sampleDay(
    videos: [
      for (var i = 0; i < n; i++)
        {
          'id': 'id-$i',
          'videoId': 'abcdefghi${i.toString().padLeft(2, '0')}',
          'title': 'Talk $i',
          'speaker': 'Speaker $i',
          'description': null,
          'category': i.isEven ? 'Namaz' : 'Akhlaq',
          'language': 'Urdu',
          'durationSeconds': null,
          'url':
              'https://www.youtube.com/watch?v=abcdefghi${i.toString().padLeft(2, '0')}',
          'thumbnailUrl': null,
        },
    ],
  ),
  registry,
);

/// One talk from a site the app has no player for.
DailyVideos dailyVideosFromOtherPlatform() => dailyVideosFromJson(
  sampleDay(
    videos: [
      {
        'id': 'other-1',
        'videoId': '76979871',
        'title': 'A talk elsewhere',
        'speaker': 'Someone',
        'description': null,
        'category': 'Namaz',
        'language': 'Urdu',
        'durationSeconds': 600,
        'url': 'https://vimeo.com/76979871',
        'thumbnailUrl': null,
      },
    ],
  ),
  registry,
);
