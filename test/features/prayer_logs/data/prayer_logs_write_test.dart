import 'dart:io';

import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_remote_datasource.dart';
import 'package:deen_companion/features/prayer_logs/data/prayer_logs_repository_impl.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log_failure.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_logs_repository.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_support/dio_test_support.dart';

const _logJson = {
  'id': 'uuid-1',
  'prayer': 'asr',
  'date': '2026-10-13',
  'status': 'on_time',
  'points': 5,
  'snapUrl': 'https://res.cloudinary.com/x?sig=1',
  'windowStartsAt': '2026-10-13T10:05:00.000Z',
  'windowEndsAt': '2026-10-13T12:25:00.000Z',
  'loggedAt': '2026-10-13T10:30:00.000Z',
};

DioException _http(int status, Map<String, dynamic> body) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/'),
  ),
);

void main() {
  late MockDio dio;
  late PrayerLogsRepositoryImpl repo;
  late Directory tmp;
  late String photo;

  setUpAll(() => registerFallbackValue(FormData()));

  setUp(() {
    dio = MockDio();
    repo = PrayerLogsRepositoryImpl(PrayerLogsRemoteDataSourceImpl(dio));
    tmp = Directory.systemTemp.createTempSync('prayer_log_test');
    photo = '${tmp.path}/snap.jpg';
    File(photo).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  When<Future<Response<dynamic>>> stubPost() =>
      when(() => dio.post(any(), data: any(named: 'data')));

  group('logPrayer', () {
    test('uploads one `file` part and nothing else', () async {
      stubPost().thenAnswer(
        (_) async => okResponse({'success': true, 'data': _logJson}),
      );
      final r = await repo.logPrayer(photo);
      expect((r as Success).data.id, 'uuid-1');

      final form =
          verify(
                () => dio.post(
                  ApiEndpoints.prayerLogs,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as FormData;
      expect(form.files, hasLength(1));
      expect(form.fields, isEmpty);
      final part = form.files.single;
      expect(part.key, 'file');
      expect(part.value.filename, 'snap.jpg');
      expect(part.value.contentType.toString(), 'image/jpeg');
    });

    test('png and webp keep their own content type', () async {
      stubPost().thenAnswer(
        (_) async => okResponse({'success': true, 'data': _logJson}),
      );
      final png = '${tmp.path}/a.PNG';
      File(png).writeAsBytesSync([1]);
      await repo.logPrayer(png);
      final form =
          verify(
                () => dio.post(any(), data: captureAny(named: 'data')),
              ).captured.single
              as FormData;
      expect(form.files.single.value.contentType.toString(), 'image/png');
      expect(form.files.single.value.filename, 'snap.png');
    });

    test('over 5 MB is refused before any request', () async {
      final big = '${tmp.path}/big.jpg';
      File(big).writeAsBytesSync(
        List.filled(PrayerLogsRepository.maxPhotoBytes + 1, 0),
      );
      final f = (await repo.logPrayer(big) as Error).failure;
      expect((f as PrayerLogFailure).code, PrayerLogErrorCode.fileTooLarge);
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });

    test('exactly 5 MB is allowed', () async {
      stubPost().thenAnswer(
        (_) async => okResponse({'success': true, 'data': _logJson}),
      );
      final edge = '${tmp.path}/edge.jpg';
      File(
        edge,
      ).writeAsBytesSync(List.filled(PrayerLogsRepository.maxPhotoBytes, 0));
      expect(await repo.logPrayer(edge), isA<Success>());
    });

    test('a missing file is an error, not a crash', () async {
      final r = await repo.logPrayer('${tmp.path}/nope.jpg');
      expect((r as Error).failure, isA<UnexpectedFailure>());
    });

    test('422 carries the next prayer and when it starts', () async {
      stubPost().thenThrow(
        _http(422, {
          'success': false,
          'message': 'No active prayer window',
          'code': 'NO_ACTIVE_PRAYER_WINDOW',
          'data': {
            'nextPrayer': 'maghrib',
            'startsAt': '2026-10-13T12:25:00.000Z',
          },
        }),
      );
      final f =
          (await repo.logPrayer(photo) as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.noActiveWindow);
      expect(f.nextPrayer, PrayerName.maghrib);
      expect(f.nextStartsAt, DateTime.utc(2026, 10, 13, 12, 25));
    });

    test('409 already logged exposes the existing log', () async {
      stubPost().thenThrow(
        _http(409, {
          'success': false,
          'message': 'Already logged',
          'code': 'PRAYER_ALREADY_LOGGED',
          'data': _logJson,
        }),
      );
      final f =
          (await repo.logPrayer(photo) as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.alreadyLogged);
      expect(f.existingLog!.id, 'uuid-1');
    });

    test('existing log nested under data.log is found too', () async {
      stubPost().thenThrow(
        _http(409, {
          'success': false,
          'message': 'Already logged',
          'code': 'PRAYER_ALREADY_LOGGED',
          'data': {'log': _logJson},
        }),
      );
      final f =
          (await repo.logPrayer(photo) as Error).failure as PrayerLogFailure;
      expect(f.existingLog!.prayer, PrayerName.asr);
    });

    test('413 from the server maps to fileTooLarge', () async {
      stubPost().thenThrow(
        _http(413, {'success': false, 'message': 'File too large'}),
      );
      final f =
          (await repo.logPrayer(photo) as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.fileTooLarge);
    });

    test('not-synced code is recognised', () async {
      stubPost().thenThrow(
        _http(409, {
          'success': false,
          'message': 'Sync first',
          'code': 'PRAYER_TIMES_NOT_SYNCED',
        }),
      );
      final f =
          (await repo.logPrayer(photo) as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.timesNotSynced);
    });
  });

  group('deleteLog', () {
    test('deletes by id', () async {
      when(
        () => dio.delete(any()),
      ).thenAnswer((_) async => okResponse({'success': true}));
      expect(await repo.deleteLog('uuid-1'), isA<Success>());
      verify(() => dio.delete(ApiEndpoints.prayerLog('uuid-1'))).called(1);
    });

    test('400 after the window closed is undoLocked', () async {
      when(
        () => dio.delete(any()),
      ).thenThrow(_http(400, {'success': false, 'message': 'Window closed'}));
      final f =
          (await repo.deleteLog('x') as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.undoLocked);
    });

    test('404 is a plain failure with its message', () async {
      when(
        () => dio.delete(any()),
      ).thenThrow(_http(404, {'success': false, 'message': 'Log not found'}));
      final f =
          (await repo.deleteLog('x') as Error).failure as PrayerLogFailure;
      expect(f.code, PrayerLogErrorCode.other);
      expect(f.message, 'Log not found');
    });
  });
}
