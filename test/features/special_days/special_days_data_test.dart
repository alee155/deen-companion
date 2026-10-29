import 'dart:io';

import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/special_days/data/special_days_models.dart';
import 'package:deen_companion/features/special_days/data/special_days_remote_datasource.dart';
import 'package:deen_companion/features/special_days/data/special_days_repository_impl.dart';
import 'package:deen_companion/features/special_days/domain/special_days.dart';
import 'package:deen_companion/features/special_days/domain/special_days_failure.dart';
import 'package:deen_companion/features/special_days/presentation/special_days_labels.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/dio_test_support.dart';

const _idle = {
  'eligible': true,
  'active': false,
  'startedAt': null,
  'startLocalDate': null,
  'endsLocalDate': null,
  'endsAt': null,
  'daysRemaining': null,
  'images': {
    'fajr': true,
    'dhuhr': true,
    'asr': false,
    'maghrib': false,
    'isha': false,
  },
  'canStartAt': null,
  'infoMessage': 'Please upload 5 different images.',
};

const _active = {
  'eligible': true,
  'active': true,
  'startedAt': '2026-10-29T09:33:52.469Z',
  'startLocalDate': '2026-10-29',
  'endsLocalDate': '2026-11-08',
  'endsAt': '2026-11-07T19:00:00.000Z',
  'daysRemaining': 10,
  'images': {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
  },
  'canStartAt': '2026-11-13T09:33:52.469Z',
  'infoMessage': 'info',
};

DioException _http(int status, String code, [String message = 'no']) =>
    DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.badResponse,
      response: Response(
        statusCode: status,
        data: {
          'success': false,
          'statusCode': status,
          'message': message,
          'code': code,
        },
        requestOptions: RequestOptions(path: '/'),
      ),
    );

void main() {
  group('specialDaysFromJson', () {
    test('an idle account: photos by prayer, nothing running', () {
      final s = specialDaysFromJson(_idle);
      expect(s.eligible, isTrue);
      expect(s.active, isFalse);
      expect(s.hasImage(PrayerName.fajr), isTrue);
      expect(s.hasImage(PrayerName.asr), isFalse);
      expect(s.imageCount, 2);
      expect(s.hasAllImages, isFalse);
      expect(s.missingImages, [
        PrayerName.asr,
        PrayerName.maghrib,
        PrayerName.isha,
      ]);
      expect(s.endsAt, isNull);
      expect(s.infoMessage, 'Please upload 5 different images.');
    });

    test('a running period: dates, days left and the next allowed start', () {
      final s = specialDaysFromJson(_active);
      expect(s.active, isTrue);
      expect(s.daysRemaining, 10);
      expect(s.endsLocalDate, '2026-11-08');
      expect(s.endsAt, DateTime.utc(2026, 11, 7, 19));
      expect(s.canStartAt, DateTime.utc(2026, 11, 13, 9, 33, 52, 469));
      expect(s.hasAllImages, isTrue);
    });

    test('a male or unset account only says it is not eligible', () {
      final s = specialDaysFromJson({'eligible': false, 'genderSet': true});
      expect(s.eligible, isFalse);
      expect(s.images, isEmpty);
      expect(s.imageCount, 0);
    });

    test('isTooSoon compares with the next allowed start', () {
      final s = specialDaysFromJson(_active);
      expect(s.isTooSoon(DateTime.utc(2026, 11, 1)), isTrue);
      expect(s.isTooSoon(DateTime.utc(2026, 11, 14)), isFalse);
      expect(specialDaysFromJson(_idle).isTooSoon(DateTime.now()), isFalse);
    });
  });

  group('specialDayImagesFromJson', () {
    test('the live shape: a link and a time, or null', () {
      final images = specialDayImagesFromJson({
        'images': {
          'fajr': {
            'url':
                'https://res.cloudinary.com/x/image/authenticated/s--a--/v1/f?_a=B',
            'updatedAt': '2026-10-29T11:39:00.599Z',
          },
          'dhuhr': null,
          'asr': null,
          'maghrib': null,
          'isha': null,
        },
      });
      expect(images.keys, [PrayerName.fajr]);
      expect(images[PrayerName.fajr]!.url.host, 'res.cloudinary.com');
      expect(
        images[PrayerName.fajr]!.updatedAt,
        DateTime.utc(2026, 10, 29, 11, 39, 0, 599),
      );
    });

    test('an entry that can not be read is left out, not a crash', () {
      final images = specialDayImagesFromJson({
        'images': {
          'fajr': {'url': 'not a url', 'updatedAt': '2026-10-29T11:39:00Z'},
          'dhuhr': {'url': 'https://x.test/a.jpg', 'updatedAt': 'yesterday'},
          'asr': {'url': 'https://x.test/b.jpg'},
          'maghrib': 'garbage',
          'isha': {
            'url': 'https://x.test/c.jpg',
            'updatedAt': '2026-10-29T11:39:00Z',
          },
        },
      });
      expect(images.keys, [PrayerName.isha]);
      expect(specialDayImagesFromJson({}), isEmpty);
      expect(specialDayImagesFromJson({'images': 'x'}), isEmpty);
    });
  });

  group('remote data source', () {
    late MockDio dio;
    late SpecialDaysRemoteDataSourceImpl ds;
    setUp(() {
      dio = MockDio();
      ds = SpecialDaysRemoteDataSourceImpl(dio);
    });

    test('getState reads GET /exemption', () async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': _idle}));
      final s = await ds.getState();
      expect(s.imageCount, 2);
      verify(() => dio.get(ApiEndpoints.exemption)).called(1);
    });

    test('getImages reads GET /exemption/images', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': {
            'images': {
              'fajr': {
                'url': 'https://x.test/a.jpg',
                'updatedAt': '2026-10-29T11:39:00Z',
              },
              'dhuhr': null,
              'asr': null,
              'maghrib': null,
              'isha': null,
            },
          },
        }),
      );
      final images = await ds.getImages();
      expect(images.keys, [PrayerName.fajr]);
      verify(() => dio.get(ApiEndpoints.exemptionImages)).called(1);
    });

    test('setActive puts {active} to /exemption/status', () async {
      when(
        () => dio.put(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': _active}));
      final s = await ds.setActive(true);
      expect(s.active, isTrue);
      verify(
        () => dio.put(ApiEndpoints.exemptionStatus, data: {'active': true}),
      ).called(1);
    });

    test(
      'uploadImage sends one multipart `file` to the prayer\'s path',
      () async {
        when(
          () => dio.put(any(), data: any(named: 'data')),
        ).thenAnswer((_) async => okResponse({'success': true, 'data': _idle}));
        final tmp = Directory.systemTemp.createTempSync('sd');
        addTearDown(() => tmp.deleteSync(recursive: true));
        final f = File('${tmp.path}/a.PNG')..writeAsBytesSync([1, 2, 3]);
        await ds.uploadImage(PrayerName.asr, f.path);
        final form =
            verify(
                  () => dio.put(
                    ApiEndpoints.exemptionImage('asr'),
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as FormData;
        expect(form.fields, isEmpty);
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'asr.png');
        expect(form.files.single.value.contentType.toString(), 'image/png');
      },
    );

    test('removeImage deletes the prayer\'s photo', () async {
      when(
        () => dio.delete(any()),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': _idle}));
      await ds.removeImage(PrayerName.fajr);
      verify(() => dio.delete(ApiEndpoints.exemptionImage('fajr'))).called(1);
    });
  });

  group('repository', () {
    late MockDio dio;
    late SpecialDaysRepositoryImpl repo;
    setUp(() {
      dio = MockDio();
      repo = SpecialDaysRepositoryImpl(SpecialDaysRemoteDataSourceImpl(dio));
    });

    Future<SpecialDaysFailure> failureOfStart(int status, String code) async {
      when(
        () => dio.put(any(), data: any(named: 'data')),
      ).thenThrow(_http(status, code));
      return (await repo.setActive(true) as Error).failure
          as SpecialDaysFailure;
    }

    test('every code the screens react to is kept', () async {
      expect(
        (await failureOfStart(409, 'EXEMPTION_IMAGES_REQUIRED')).code,
        SpecialDaysErrorCode.imagesRequired,
      );
      expect(
        (await failureOfStart(409, 'EXEMPTION_TOO_SOON')).code,
        SpecialDaysErrorCode.tooSoon,
      );
      expect(
        (await failureOfStart(409, 'PRAYER_TIMES_NOT_SYNCED')).code,
        SpecialDaysErrorCode.timesNotSynced,
      );
      expect(
        (await failureOfStart(409, 'EXEMPTION_ALREADY_ACTIVE')).code,
        SpecialDaysErrorCode.alreadyActive,
      );
      expect(
        (await failureOfStart(403, 'EXEMPTION_NOT_AVAILABLE')).code,
        SpecialDaysErrorCode.notAvailable,
      );
      expect(
        (await failureOfStart(500, 'WHATEVER')).code,
        SpecialDaysErrorCode.other,
      );
    });

    test('the server\'s message reaches the failure', () async {
      when(() => dio.put(any(), data: any(named: 'data'))).thenThrow(
        _http(409, 'EXEMPTION_IMAGES_REQUIRED', 'Please upload 5 images.'),
      );
      final f = (await repo.setActive(true) as Error).failure;
      expect(f.message, 'Please upload 5 images.');
    });

    test('a photo over 5 MB is refused before the upload', () async {
      final tmp = Directory.systemTemp.createTempSync('sd');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final big = File('${tmp.path}/big.jpg')
        ..writeAsBytesSync(List.filled(5 * 1024 * 1024 + 1, 0));
      final f =
          (await repo.uploadImage(PrayerName.fajr, big.path) as Error).failure
              as SpecialDaysFailure;
      expect(f.code, SpecialDaysErrorCode.fileTooLarge);
      verifyNever(() => dio.put(any(), data: any(named: 'data')));
    });

    test('a missing file fails without calling the server', () async {
      final r = await repo.uploadImage(PrayerName.fajr, '/nope/x.jpg');
      expect(r, isA<Error>());
      verifyNever(() => dio.put(any(), data: any(named: 'data')));
    });

    test('getImages: not available for this account keeps its code', () async {
      when(
        () => dio.get(any()),
      ).thenThrow(_http(403, 'EXEMPTION_NOT_AVAILABLE'));
      final f = (await repo.getImages() as Error).failure as SpecialDaysFailure;
      expect(f.code, SpecialDaysErrorCode.notAvailable);
    });

    test('a network failure is a NetworkFailure', () async {
      when(() => dio.get(any())).thenThrow(dioError());
      final f = (await repo.getState() as Error).failure;
      expect(f, isA<NetworkFailure>());
    });
  });

  group('labels', () {
    test('days left', () {
      expect(daysLeftText(10), '10 days left');
      expect(daysLeftText(1), '1 day left');
      expect(daysLeftText(0), 'Ends today');
      expect(daysLeftText(null), '');
    });

    test('short dates', () {
      expect(shortLocalDate('2026-11-08'), '8 Nov');
      expect(shortLocalDate(null), isNull);
      expect(shortLocalDate('nonsense'), isNull);
    });

    test('messages say what to do', () {
      String msg(SpecialDaysErrorCode c, {SpecialDays? state}) =>
          specialDaysMessage(
            SpecialDaysFailure('server words', code: c),
            state: state,
          );
      expect(msg(SpecialDaysErrorCode.imagesRequired), 'server words');
      expect(
        msg(SpecialDaysErrorCode.timesNotSynced),
        contains('Prayer Times'),
      );
      expect(msg(SpecialDaysErrorCode.imageDuplicate), contains('different'));
      expect(msg(SpecialDaysErrorCode.active), contains('while special days'));
      expect(
        msg(
          SpecialDaysErrorCode.tooSoon,
          state: SpecialDays(
            eligible: true,
            canStartAt: DateTime.utc(2026, 11, 13, 12),
          ),
        ),
        'You can start special days again on 13 Nov.',
      );
      expect(
        specialDaysMessage(const NetworkFailure()),
        const NetworkFailure().message,
      );
    });
  });
}
