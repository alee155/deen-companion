import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/videos/data/datasources/videos_remote_datasource.dart';
import 'package:deen_companion/features/videos/data/models/daily_videos_model.dart';
import 'package:deen_companion/features/videos/data/repositories/videos_repository_impl.dart';
import 'package:deen_companion/features/videos/domain/entities/daily_videos.dart';
import 'package:deen_companion/features/videos/domain/entities/video_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_storage_service.dart';
import '../_support/dio_test_support.dart';
import '_videos_support.dart';

class _Remote extends Mock implements VideosRemoteDataSource {}

void main() {
  group('parsing the real response', () {
    test('the day, and every field of a video', () {
      final d = sampleDaily();
      expect(d.date, '2026-10-29');
      expect(d.validUntil, DateTime.utc(2099));
      expect(d.videos, hasLength(3));

      final v = d.videos.first;
      expect(v.id, '68de0e4c-d381-11f1-a6bb-005056010280');
      expect(v.title, 'The Love of Allah | Life Changing Bayan');
      expect(v.speaker, 'Maulana Tariq Jameel');
      expect(v.description, 'Allah ki mohabbat par bayan (Feb 2025)');
      expect(v.category, 'Allah ki Mohabbat');
      expect(v.language, 'Urdu');
      expect(v.duration, isNull, reason: 'durationSeconds is null today');
      expect(
        v.thumbnail.toString(),
        'https://img.youtube.com/vi/5ES0cFPNpbE/hqdefault.jpg',
      );
    });

    test('the platform is worked out from the url, not given', () {
      final s = sampleDaily().videos.first.source;
      expect(s.platform, VideoPlatform.youtube);
      expect(s.videoId, '5ES0cFPNpbE');
      expect(s.canPlayInApp, isTrue);
      expect(s.uri.toString(), 'https://www.youtube.com/watch?v=5ES0cFPNpbE');
    });

    test('categories come in order of first appearance, without repeats', () {
      expect(sampleDaily().categories, ['Allah ki Mohabbat', 'Namaz']);
    });

    test('a duration is read when the API has one', () {
      final d = dailyVideosFromJson(
        sampleDay(
          videos: [
            {
              ...sampleDay()['videos'][0] as Map<String, dynamic>,
              'durationSeconds': 754,
            },
            {
              ...sampleDay()['videos'][1] as Map<String, dynamic>,
              'durationSeconds': 0,
            },
          ],
        ),
        registry,
      );
      expect(d.videos[0].duration, const Duration(minutes: 12, seconds: 34));
      expect(d.videos[1].duration, isNull);
    });

    test('a missing picture falls back to the platform\'s own', () {
      final d = dailyVideosFromJson(
        sampleDay(
          videos: [
            {
              ...sampleDay()['videos'][0] as Map<String, dynamic>,
              'thumbnailUrl': null,
            },
          ],
        ),
        registry,
      );
      expect(
        d.videos.single.thumbnail.toString(),
        'https://img.youtube.com/vi/5ES0cFPNpbE/hqdefault.jpg',
      );
    });

    test('a link from another platform still shows, to open outside', () {
      final d = dailyVideosFromJson(
        sampleDay(
          videos: [
            {
              ...sampleDay()['videos'][0] as Map<String, dynamic>,
              'url': 'https://vimeo.com/76979871',
              'videoId': '76979871',
              'thumbnailUrl': null,
            },
          ],
        ),
        registry,
      );
      final v = d.videos.single;
      expect(v.source.platform, VideoPlatform.other);
      expect(v.source.canPlayInApp, isFalse);
      expect(v.thumbnail, isNull);
    });

    test('one bad entry is skipped, never the whole day', () {
      final ok = sampleDay()['videos'][0] as Map<String, dynamic>;
      final d = dailyVideosFromJson(
        sampleDay(
          videos: [
            {...ok, 'title': ''},
            {...ok, 'url': 'javascript:alert(1)'},
            {...ok, 'url': 'not a url'},
            {...ok, 'id': null},
            ok,
          ],
        ),
        registry,
      );
      expect(d.videos, hasLength(1));
    });

    test('toJson and back keeps everything', () {
      final d = sampleDaily();
      expect(dailyVideosFromJson(dailyVideosToJson(d), registry), d);
    });
  });

  group('DailyVideos', () {
    test('valid until the instant the set changes', () {
      final d = sampleDaily(validUntil: '2026-10-29T19:00:00.000Z');
      expect(d.isValidAt(DateTime.utc(2026, 10, 29, 18, 59)), isTrue);
      expect(d.isValidAt(DateTime.utc(2026, 10, 29, 19)), isFalse);
    });

    test('finds a video by id', () {
      final d = sampleDaily();
      expect(d.byId(d.videos[1].id), d.videos[1]);
      expect(d.byId('nope'), isNull);
    });
  });

  group('remote data source', () {
    late MockDio dio;
    late VideosRemoteDataSourceImpl ds;
    setUp(() {
      dio = MockDio();
      ds = VideosRemoteDataSourceImpl(dio);
    });

    test('asks for the count and returns the data object', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => okResponse({'success': true, 'data': sampleDay()}),
      );
      final data = await ds.getRandom(count: 10);
      expect(data['date'], '2026-10-29');
      verify(
        () =>
            dio.get(ApiEndpoints.videosRandom, queryParameters: {'count': 10}),
      ).called(1);
    });

    test('no count is not sent', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => okResponse({'success': true, 'data': sampleDay()}),
      );
      await ds.getRandom();
      verify(
        () => dio.get(ApiEndpoints.videosRandom, queryParameters: {}),
      ).called(1);
    });
  });

  group('repository', () {
    late _Remote remote;
    late InMemoryStorageService storage;
    late DateTime clock;
    late VideosRepositoryImpl repo;

    setUp(() {
      remote = _Remote();
      storage = InMemoryStorageService();
      clock = DateTime.utc(2026, 10, 29, 10);
      repo = VideosRepositoryImpl(
        remote: remote,
        cache: HiveCacheStore(storage),
        now: () => clock,
      );
    });

    void serves(Map<String, dynamic> day) => when(
      () => remote.getRandom(count: any(named: 'count')),
    ).thenAnswer((_) async => day);

    test('asks for the most the API gives, once, and keeps it', () async {
      serves(sampleDay());
      final r = await repo.getDailyVideos();
      expect((r as Success<DailyVideos>).data.videos, hasLength(3));
      verify(() => remote.getRandom(count: 10)).called(1);
      expect(repo.getCached(), isNotNull);
    });

    test('the saved set is used all day: no second request', () async {
      serves(sampleDay());
      await repo.getDailyVideos();
      clock = DateTime.utc(2026, 10, 29, 18);
      final again = await repo.getDailyVideos();
      expect(again, isA<Success<DailyVideos>>());
      verify(() => remote.getRandom(count: any(named: 'count'))).called(1);
    });

    test(
      'at midnight the saved set is no longer today\'s: ask again',
      () async {
        serves(sampleDay());
        await repo.getDailyVideos();
        clock = DateTime.utc(2026, 10, 29, 19, 1);
        expect(repo.getCached(), isNull);
        serves(sampleDay(validUntil: '2026-10-30T19:00:00.000Z'));
        await repo.getDailyVideos();
        verify(() => remote.getRandom(count: any(named: 'count'))).called(2);
      },
    );

    test('forceRefresh asks again even when the saved set is valid', () async {
      serves(sampleDay());
      await repo.getDailyVideos();
      await repo.getDailyVideos(forceRefresh: true);
      verify(() => remote.getRandom(count: any(named: 'count'))).called(2);
    });

    test('offline, yesterday\'s set is better than nothing', () async {
      serves(sampleDay());
      await repo.getDailyVideos();
      clock = DateTime.utc(2026, 10, 30, 8);
      // The data source maps a Dio error; the repository sees its exception.
      when(
        () => remote.getRandom(count: any(named: 'count')),
      ).thenThrow(const NetworkException());
      final r = await repo.getDailyVideos();
      expect(r, isA<Success<DailyVideos>>());
    });

    test('offline with nothing saved is a network failure', () async {
      when(
        () => remote.getRandom(count: any(named: 'count')),
      ).thenThrow(const NetworkException());
      final r = await repo.getDailyVideos();
      expect((r as Error).failure, isA<NetworkFailure>());
    });

    test('a server error with nothing saved carries its message', () async {
      when(
        () => remote.getRandom(count: any(named: 'count')),
      ).thenThrow(const ServerException('Too many requests'));
      final r = await repo.getDailyVideos();
      expect((r as Error).failure.message, 'Too many requests');
    });

    test('an unreadable saved copy is ignored, not a crash', () async {
      await storage.put('api_cache_box', 'daily_bayan_videos', {
        'data': {'videos': 'garbage'},
        'fetched_at': DateTime.now().toIso8601String(),
      });
      expect(repo.getCached(), isNull);
    });
  });
}
