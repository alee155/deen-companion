import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/theme/app_typography.dart';

/// Reader typography settings, shared by every reading surface in the app
/// (Hadith, Juz, ...) and persisted locally so the size a reader chose is
/// still there next time they
/// open the app.
///
/// Arabic and English scale independently: people who want large Arabic
/// calligraphy don't necessarily want an equally large translation, and vice
/// versa.
@immutable
class ReadingPreferences {
  final double arabicScale;
  final double englishScale;
  final bool showArabic;
  final bool showTranslation;

  const ReadingPreferences({
    this.arabicScale = 1.0,
    this.englishScale = 1.0,
    this.showArabic = true,
    this.showTranslation = true,
  });

  static const double minScale = 0.85;
  static const double maxScale = 1.75;

  /// Discrete steps rather than a continuous slider: every stop is a size
  /// someone would actually choose, and the slider is far easier to land on
  /// with a thumb.
  static const int scaleDivisions = 6;

  /// Base sizes, before scaling. Arabic is set noticeably larger than the
  /// translation because the script needs the extra height to stay legible.
  static double get arabicBaseSize => 21.sp;
  static double get englishBaseSize => 15.5.sp;

  TextStyle get arabicStyle => AppTypography.arabicBody.copyWith(
    fontSize: arabicBaseSize * arabicScale,
    // Arabic diacritics need real breathing room between lines.
    height: 2.05,
  );

  TextStyle get englishStyle => AppTypography.bodyLarge.copyWith(
    fontSize: englishBaseSize * englishScale,
    height: 1.78,
  );

  /// Label shown next to each slider — a percentage reads more clearly than
  /// a raw multiplier.
  String get arabicLabel => '${(arabicScale * 100).round()}%';
  String get englishLabel => '${(englishScale * 100).round()}%';

  bool get isDefault =>
      arabicScale == 1.0 &&
      englishScale == 1.0 &&
      showArabic &&
      showTranslation;

  ReadingPreferences copyWith({
    double? arabicScale,
    double? englishScale,
    bool? showArabic,
    bool? showTranslation,
  }) {
    return ReadingPreferences(
      arabicScale: arabicScale ?? this.arabicScale,
      englishScale: englishScale ?? this.englishScale,
      showArabic: showArabic ?? this.showArabic,
      showTranslation: showTranslation ?? this.showTranslation,
    );
  }
}

class ReadingPreferencesNotifier extends Notifier<ReadingPreferences> {
  static const _arabicScaleKey = 'reader_arabic_scale';
  static const _englishScaleKey = 'reader_english_scale';
  static const _showArabicKey = 'reader_show_arabic';
  static const _showTranslationKey = 'reader_show_translation';

  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  ReadingPreferences build() {
    final box = AppConstants.settingsBoxName;
    return ReadingPreferences(
      arabicScale: _clamp(_storage.get<double>(box, _arabicScaleKey) ?? 1.0),
      englishScale: _clamp(_storage.get<double>(box, _englishScaleKey) ?? 1.0),
      showArabic: _storage.get<bool>(box, _showArabicKey) ?? true,
      showTranslation: _storage.get<bool>(box, _showTranslationKey) ?? true,
    );
  }

  double _clamp(double value) =>
      value.clamp(ReadingPreferences.minScale, ReadingPreferences.maxScale);

  Future<void> setArabicScale(double scale) async {
    state = state.copyWith(arabicScale: _clamp(scale));
    await _put(_arabicScaleKey, state.arabicScale);
  }

  Future<void> setEnglishScale(double scale) async {
    state = state.copyWith(englishScale: _clamp(scale));
    await _put(_englishScaleKey, state.englishScale);
  }

  /// Both blocks can't be hidden at once — that would leave an empty page.
  Future<void> setShowArabic(bool show) async {
    if (!show && !state.showTranslation) return;
    state = state.copyWith(showArabic: show);
    await _put(_showArabicKey, show);
  }

  Future<void> setShowTranslation(bool show) async {
    if (!show && !state.showArabic) return;
    state = state.copyWith(showTranslation: show);
    await _put(_showTranslationKey, show);
  }

  Future<void> reset() async {
    state = const ReadingPreferences();
    await _put(_arabicScaleKey, 1.0);
    await _put(_englishScaleKey, 1.0);
    await _put(_showArabicKey, true);
    await _put(_showTranslationKey, true);
  }

  Future<void> _put(String key, Object value) =>
      _storage.put(AppConstants.settingsBoxName, key, value);
}

final readingPreferencesProvider =
    NotifierProvider<ReadingPreferencesNotifier, ReadingPreferences>(
      ReadingPreferencesNotifier.new,
    );
