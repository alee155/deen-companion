import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/network_info.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/daily_content/data/daily_content_remote_source.dart';
import 'package:deen_companion/features/daily_content/data/daily_content_store.dart';
import 'package:deen_companion/features/daily_content/data/repositories/daily_content_repository_impl.dart';
import 'package:deen_companion/features/daily_content/domain/daily_notification_config.dart';
import 'package:deen_companion/features/daily_content/domain/entities/daily_content.dart';
import 'package:deen_companion/features/daily_content/domain/notification_text.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_model.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/shared/domain/translation_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_storage_service.dart';

const _en = 'Allah - there is no deity except Him, the Ever-Living.';
const _ur = 'اللہ ہی معبود ہے، زندہ ہے، سب کو تھامے رکھنے والا ہے۔';

DailyAyah _ayah({String? urdu = _ur}) => DailyAyah(
  surahNumber: 2,
  surahNameEnglish: 'Al-Baqarah',
  surahNameArabic: 'البقرة',
  ayahNumber: 255,
  arabic: 'ar',
  translation: _en,
  translationUrdu: urdu,
);

const _hadith = Hadith(
  id: 'bukhari-1',
  collection: 'bukhari',
  collectionName: 'Sahih al-Bukhari',
  hadithNumber: 1,
  arabic: 'ar',
  english: 'en',
  grade: 'Sahih',
);

const _hadithModel = HadithModel(
  id: 'bukhari-1',
  collection: 'bukhari',
  collectionName: 'Sahih al-Bukhari',
  hadithNumber: 1,
  arabic: 'ar',
  english: 'en',
  grade: 'Sahih',
);

class _Remote extends Mock implements DailyContentRemoteSource {}

class _Net implements NetworkInfo {
  bool connected;
  _Net(this.connected);
  @override
  Future<bool> get isConnected async => connected;
}

void main() {
  group('DailyAyah', () {
    test('English by default; Urdu when chosen', () {
      final a = _ayah();
      expect(a.translationIn(TranslationLanguage.english), _en);
      expect(a.translationIn(TranslationLanguage.urdu), _ur);
      expect(a.showsUrduFor(TranslationLanguage.urdu), isTrue);
      expect(a.showsUrduFor(TranslationLanguage.english), isFalse);
    });

    test('a verse with no Urdu is empty in Urdu, never the English', () {
      for (final none in [null, '', '  ']) {
        final a = _ayah(urdu: none);
        expect(a.translationIn(TranslationLanguage.urdu), '');
        expect(a.showsUrduFor(TranslationLanguage.urdu), isFalse);
        expect(a.urduMissingFor(TranslationLanguage.urdu), isTrue);
        expect(a.urduMissingFor(TranslationLanguage.english), isFalse);
        // And sharing it leaves the translation out rather than using English.
        final shared = a.toShareText(language: TranslationLanguage.urdu);
        expect(shared, isNot(contains(_en)));
        expect(shared, contains('ar'));
      }
    });

    test('share text follows the language', () {
      expect(_ayah().toShareText(), contains(_en));
      expect(_ayah().toShareText(), isNot(contains(_ur)));
      final urdu = _ayah().toShareText(language: TranslationLanguage.urdu);
      expect(urdu, contains(_ur));
      expect(urdu, isNot(contains(_en)));
      expect(urdu, contains('ar')); // Arabic is untouched
    });

    test('round-trips Urdu; content saved before Urdu reads as "unknown"', () {
      final back = DailyAyah.fromJson(_ayah().toJson());
      expect(back.translationUrdu, _ur);
      expect(back.urduKnown, isTrue);

      final old = _ayah(urdu: null).toJson();
      expect(old.containsKey('translation_urdu'), isFalse);
      final restored = DailyAyah.fromJson(old);
      expect(restored.urduKnown, isFalse);
      // "none for this verse" is different from "not fetched".
      expect(DailyAyah.fromJson(_ayah(urdu: '').toJson()).urduKnown, isTrue);
    });
  });

  group('DailyNotificationText', () {
    DailyContent content({String? urdu = _ur}) => DailyContent(
      dateKey: '2026-01-01',
      ayah: _ayah(urdu: urdu),
      hadith: _hadith,
    );

    test('English is exactly as before', () {
      final text = DailyNotificationText.preview(content());
      expect(text, startsWith('“$_en”'));
      expect(text, contains('Hadith: Sahih al-Bukhari, #1'));
    });

    test('Urdu: the verse and the hadith line are in Urdu', () {
      final text = DailyNotificationText.preview(
        content(),
        language: TranslationLanguage.urdu,
      );
      expect(text, contains(_ur));
      expect(text, isNot(contains('Allah')));
      expect(text, contains('2:255'));
      expect(text, contains('حدیث: صحیح بخاری'));
      expect(text, isNot(contains('Hadith:')));
    });

    test('Urdu with no Urdu verse text says so, never quotes the English', () {
      final text = DailyNotificationText.preview(
        content(urdu: ''),
        language: TranslationLanguage.urdu,
      );
      expect(text, contains(TranslationLanguage.urduUnavailableInUrdu));
      expect(text, isNot(contains('Allah')));
      expect(text, contains('2:255'));
      expect(text, contains('حدیث: صحیح بخاری'));
    });

    test('fallback wording follows the language', () {
      expect(
        DailyNotificationText.preview(null),
        DailyNotificationText.fallback,
      );
      expect(
        DailyNotificationText.preview(null, language: TranslationLanguage.urdu),
        DailyNotificationText.fallbackUrdu,
      );
    });

    test('every collection the app lists has an Urdu name', () {
      for (final key in [
        'bukhari',
        'muslim',
        'abudawud',
        'tirmidhi',
        'ibnmajah',
        'nasai',
        'malik',
        'nawawi',
        'qudsi',
        'dehlawi',
      ]) {
        expect(
          DailyNotificationText.urduCollectionName(key),
          isNotNull,
          reason: key,
        );
      }
      expect(DailyNotificationText.urduCollectionName('nope'), isNull);
    });

    test('the notification title follows the language', () {
      const c = DailyNotificationConfig.production;
      expect(
        c.titleFor(TranslationLanguage.english),
        'Ayat & Hadith of the Day',
      );
      expect(c.titleFor(TranslationLanguage.urdu), 'آج کی آیت اور حدیث');
    });
  });

  group('DailyContentRepositoryImpl and Urdu', () {
    late _Remote remote;
    late DailyContentStore store;
    late _Net net;
    late DailyContentRepositoryImpl repo;

    setUp(() {
      remote = _Remote();
      store = DailyContentStore(InMemoryStorageService());
      net = _Net(true);
      repo = DailyContentRepositoryImpl(
        remote: remote,
        store: store,
        networkInfo: net,
      );
      when(() => remote.getAyah(any(), any())).thenAnswer((_) async => _ayah());
      when(
        () => remote.getHadith(any(), any()),
      ).thenAnswer((_) async => _hadithModel);
    });

    const day = '2026-03-04';

    test(
      'content that already has Urdu is served from the saved copy',
      () async {
        await store.writeContent(day, _ayah(), _hadithModel);
        final r = await repo.fetch(day) as Success<DailyContent>;
        expect(r.data.ayah.translationUrdu, _ur);
        verifyNever(() => remote.getAyah(any(), any()));
      },
    );

    test('content saved before Urdu is refreshed once, when online', () async {
      await store.writeContent(day, _ayah(urdu: null), _hadithModel);
      final r = await repo.fetch(day) as Success<DailyContent>;
      expect(r.data.ayah.translationUrdu, _ur);
      verify(() => remote.getAyah(any(), any())).called(1);
      // And now it is saved with Urdu, so it isn't refreshed again.
      expect(store.readContent(day)!.ayah.urduKnown, isTrue);
    });

    test('offline, old content is still served (English)', () async {
      net.connected = false;
      await store.writeContent(day, _ayah(urdu: null), _hadithModel);
      final r = await repo.fetch(day) as Success<DailyContent>;
      expect(r.data.ayah.urduKnown, isFalse);
      verifyNever(() => remote.getAyah(any(), any()));
    });

    test(
      'a failed refresh keeps the old content rather than an error',
      () async {
        await store.writeContent(day, _ayah(urdu: null), _hadithModel);

        // A server error, and an unexpected crash: both keep the saved day.
        for (final failure in [ServerException('down'), Exception('boom')]) {
          when(() => remote.getAyah(any(), any())).thenThrow(failure);
          final r = await repo.fetch(day);
          expect(r, isA<Success<DailyContent>>(), reason: '$failure');
          expect((r as Success<DailyContent>).data.ayah.urduKnown, isFalse);
        }
      },
    );

    test('with nothing saved, a failure is still an error', () async {
      when(() => remote.getAyah(any(), any())).thenThrow(Exception('boom'));
      expect(await repo.fetch(day), isA<Error<DailyContent>>());
    });
  });
}
