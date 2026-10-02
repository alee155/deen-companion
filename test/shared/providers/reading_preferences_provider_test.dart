import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/shared/providers/reading_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/fake_storage.dart';

void main() {
  late FakeStorage storage;
  const box = AppConstants.settingsBoxName;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => storage = FakeStorage());

  group('ReadingPreferences', () {
    test('defaults and isDefault', () {
      const p = ReadingPreferences();
      expect(p.isDefault, isTrue);
      expect(p.arabicLabel, '100%');
      expect(p.englishLabel, '100%');
    });

    test('labels round to whole percent', () {
      const p = ReadingPreferences(arabicScale: 1.234, englishScale: 0.855);
      expect(p.arabicLabel, '123%');
      expect(p.englishLabel, '86%');
      expect(p.isDefault, isFalse);
    });

    test('copyWith keeps unspecified fields', () {
      const p = ReadingPreferences(arabicScale: 1.5, showArabic: false);
      final q = p.copyWith(englishScale: 1.2);
      expect(q.arabicScale, 1.5);
      expect(q.showArabic, isFalse);
      expect(q.englishScale, 1.2);
      expect(q.showTranslation, isTrue);
    });

    test('hiding either block or scaling makes it non-default', () {
      expect(
        const ReadingPreferences(showTranslation: false).isDefault,
        isFalse,
      );
      expect(const ReadingPreferences(showArabic: false).isDefault, isFalse);
    });
  });

  group('ReadingPreferencesNotifier', () {
    test('builds defaults from empty storage', () {
      expect(make().read(readingPreferencesProvider).isDefault, isTrue);
    });

    test('restores persisted values', () {
      storage.boxes[box] = {
        'reader_arabic_scale': 1.5,
        'reader_english_scale': 0.9,
        'reader_show_arabic': false,
        'reader_show_translation': true,
      };
      final p = make().read(readingPreferencesProvider);
      expect(p.arabicScale, 1.5);
      expect(p.englishScale, 0.9);
      expect(p.showArabic, isFalse);
    });

    test('out-of-range stored scales are clamped', () {
      storage.boxes[box] = {
        'reader_arabic_scale': 9.0,
        'reader_english_scale': 0.1,
      };
      final p = make().read(readingPreferencesProvider);
      expect(p.arabicScale, ReadingPreferences.maxScale);
      expect(p.englishScale, ReadingPreferences.minScale);
    });

    test('setArabicScale clamps and persists the clamped value', () async {
      final c = make();
      final n = c.read(readingPreferencesProvider.notifier);
      await n.setArabicScale(5);
      expect(c.read(readingPreferencesProvider).arabicScale, 1.75);
      expect(storage.get<double>(box, 'reader_arabic_scale'), 1.75);
      await n.setArabicScale(0);
      expect(c.read(readingPreferencesProvider).arabicScale, 0.85);
    });

    test('setEnglishScale persists independently of Arabic', () async {
      final c = make();
      await c.read(readingPreferencesProvider.notifier).setEnglishScale(1.3);
      final p = c.read(readingPreferencesProvider);
      expect(p.englishScale, 1.3);
      expect(p.arabicScale, 1.0);
      expect(storage.get<double>(box, 'reader_english_scale'), 1.3);
    });

    test('cannot hide both Arabic and translation', () async {
      final c = make();
      final n = c.read(readingPreferencesProvider.notifier);
      await n.setShowArabic(false);
      expect(c.read(readingPreferencesProvider).showArabic, isFalse);
      await n.setShowTranslation(false); // would leave nothing
      expect(c.read(readingPreferencesProvider).showTranslation, isTrue);
      expect(storage.get<bool>(box, 'reader_show_translation'), isNull);
      // Re-showing Arabic then allows hiding translation.
      await n.setShowArabic(true);
      await n.setShowTranslation(false);
      expect(c.read(readingPreferencesProvider).showTranslation, isFalse);
      expect(c.read(readingPreferencesProvider).showArabic, isTrue);
    });

    test('cannot hide Arabic when translation hidden', () async {
      final c = make();
      final n = c.read(readingPreferencesProvider.notifier);
      await n.setShowTranslation(false);
      await n.setShowArabic(false);
      expect(c.read(readingPreferencesProvider).showArabic, isTrue);
    });

    test('reset restores and persists defaults', () async {
      final c = make();
      final n = c.read(readingPreferencesProvider.notifier);
      await n.setArabicScale(1.6);
      await n.setEnglishScale(1.2);
      await n.setShowArabic(false);
      await n.reset();
      expect(c.read(readingPreferencesProvider).isDefault, isTrue);
      expect(storage.get<double>(box, 'reader_arabic_scale'), 1.0);
      expect(storage.get<bool>(box, 'reader_show_arabic'), isTrue);
    });
  });
}
