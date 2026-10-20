import 'package:flutter/material.dart';

/// Every look the app can wear: the two fixed appearances plus one per prayer
/// period for the automatic theme. [light] and [dark] are the originals; the
/// period variants keep the brand colours and shift only the ground, surfaces,
/// text tiers and warm accents (see `_Palette.forVariant`).
enum ThemeVariant {
  light,
  dark,
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha;

  /// Whether this look sits on a dark ground (drives status-bar icons and
  /// Material's brightness).
  bool get isDark => this == dark || this == fajr || this == isha;
}

/// Deen app palette — deep teal ink and warm brass on a warm parchment
/// ground in Light, and the same character re-tuned for Dark.
///
/// Every colour is exposed as a *getter* that resolves against the palette
/// currently installed by [applyBrightness], which the root widget calls
/// before building the app. That's what makes a real Light/Dark switch
/// possible: ~700 call sites across ~80 files reference `AppColors.inkText`
/// and friends by name, and they all follow the active brightness without
/// each screen having to be rewritten to read from `Theme.of(context)`.
///
/// Consequence to know about: these are no longer compile-time constants, so
/// they can't appear inside a `const` expression. Use a non-const widget
/// constructor at those call sites.
class AppColors {
  AppColors._();

  static _Palette _current = _Palette.light;

  /// Installs the palette for [brightness]. Called from the root widget on
  /// every build, before any descendant reads a colour.
  static void applyBrightness(Brightness brightness) {
    applyVariant(
      brightness == Brightness.dark ? ThemeVariant.dark : ThemeVariant.light,
    );
  }

  /// Installs the palette for [variant] (a fixed appearance or a prayer
  /// period). Called from the root widget before any descendant reads a colour.
  static void applyVariant(ThemeVariant variant) {
    _current = _Palette.forVariant(variant);
  }

  static bool get isDark => _current.isDark;

  // ── Brand — deep teal ink + brass, evoking manuscript ink and tilework ──
  //
  // In Light this is a deep ink teal carrying light text. In Dark it lifts to
  // a mid teal that reads as an accent against the near-black ground, with
  // dark text on top (the same inversion Material uses for primary).
  static Color get emeraldInk => _current.emeraldInk;
  static Color get emeraldInkDark => _current.emeraldInkDark;

  /// Text/icon colour that sits on [emeraldInk].
  static Color get onEmeraldInk => _current.onEmeraldInk;

  /// Large brand-coloured surfaces (hero cards, the mini player). Stays deep
  /// in Dark instead of lifting, so a big block of it doesn't glare.
  static Color get heroSurface => _current.heroSurface;
  static Color get onHeroSurface => _current.onHeroSurface;

  /// The wash behind hero headers, top-left to bottom-right. Light and Dark
  /// keep the original ink-to-brand gradient; each prayer period tints it to
  /// that part of the sky (deep night blue, dawn rose, midday teal, ...).
  /// [onHeroSurface] reads clearly on both ends in every look.
  static List<Color> get heroGradient => [
    _current.heroGradientStart ?? _current.heroSurface,
    _current.heroGradientEnd ?? _current.emeraldInkDark,
  ];

  static Color get gold => _current.gold;
  static Color get goldLight => _current.goldLight;

  // Secondary warm accent — vivid terracotta/amber used for the Qibla
  // needle and other high-emphasis highlights. Kept distinct from brass so
  // it still pops against both teal and parchment.
  static Color get amber => _current.amber;
  static Color get amberDeep => _current.amberDeep;

  // ── Background gradient — the app-wide wash ──
  static Color get backgroundGradientStart => _current.backgroundGradientStart;
  static Color get backgroundGradientEnd => _current.backgroundGradientEnd;

  // ── Neutrals ──
  // Names kept from the Light-only era: `parchment` is "page ground" and
  // `surfaceLight` is "card ground", whatever the current brightness.
  static Color get parchment => _current.background;
  static Color get surfaceLight => _current.surface;
  static Color get borderWarm => _current.border;
  static Color get inkText => _current.inkText;
  static Color get textSecondary => _current.textSecondary;
  static Color get textMuted => _current.textMuted;

  /// Explicitly-dark neutrals, for the few places that intentionally render
  /// dark chrome in both themes.
  static const Color backgroundDark = Color(0xFF0F1614);
  static const Color surfaceDark = Color(0xFF18211F);
  static const Color borderDark = Color(0xFF2B3835);
  static const Color textPrimaryDark = Color(0xFFECE6D6);
  static const Color textSecondaryDark = Color(0xFFB4AE9C);

  // ── Module accents — distinct hues, tuned per theme ──
  static Color get quranAccent => _current.quranAccent;
  static Color get quranAccentBg => _current.quranAccentBg;
  static Color get hadithAccent => _current.hadithAccent;
  static Color get hadithAccentBg => _current.hadithAccentBg;
  static Color get duasAccent => _current.duasAccent;
  static Color get duasAccentBg => _current.duasAccentBg;
  static Color get hijriAccent => _current.hijriAccent;
  static Color get hijriAccentBg => _current.hijriAccentBg;
  static Color get worshipAccent => _current.worshipAccent;
  static Color get worshipAccentBg => _current.worshipAccentBg;
  static Color get toolsAccent => _current.toolsAccent;
  static Color get toolsAccentBg => _current.toolsAccentBg;

  // ── Semantic ──
  static Color get success => _current.success;
  static Color get error => _current.error;
  static Color get warning => _current.gold;
  static Color get boyAccent => _current.boyAccent;
  static Color get boyAccentBg => _current.boyAccentBg;
  static Color get girlAccent => _current.girlAccent;
  static Color get girlAccentBg => _current.girlAccentBg;

  /// Card/sheet shadow — barely there on parchment, absent in Dark where
  /// elevation is carried by surface contrast instead.
  static Color get shadow => _current.shadow;
}

/// One complete set of values. Two instances exist: [light] and [dark].
@immutable
class _Palette {
  final bool isDark;

  final Color emeraldInk;
  final Color emeraldInkDark;
  final Color onEmeraldInk;
  final Color heroSurface;
  final Color onHeroSurface;

  /// Hero gradient stops; null means the default ink-to-brand pair.
  final Color? heroGradientStart;
  final Color? heroGradientEnd;
  final Color gold;
  final Color goldLight;
  final Color amber;
  final Color amberDeep;

  final Color backgroundGradientStart;
  final Color backgroundGradientEnd;

  final Color background;
  final Color surface;
  final Color border;
  final Color inkText;
  final Color textSecondary;
  final Color textMuted;

  final Color quranAccent;
  final Color quranAccentBg;
  final Color hadithAccent;
  final Color hadithAccentBg;
  final Color duasAccent;
  final Color duasAccentBg;
  final Color hijriAccent;
  final Color hijriAccentBg;
  final Color worshipAccent;
  final Color worshipAccentBg;
  final Color toolsAccent;
  final Color toolsAccentBg;

  final Color success;
  final Color error;
  final Color boyAccent;
  final Color boyAccentBg;
  final Color girlAccent;
  final Color girlAccentBg;
  final Color shadow;

  const _Palette({
    required this.isDark,
    required this.emeraldInk,
    required this.emeraldInkDark,
    required this.onEmeraldInk,
    required this.heroSurface,
    required this.onHeroSurface,
    this.heroGradientStart,
    this.heroGradientEnd,
    required this.gold,
    required this.goldLight,
    required this.amber,
    required this.amberDeep,
    required this.backgroundGradientStart,
    required this.backgroundGradientEnd,
    required this.background,
    required this.surface,
    required this.border,
    required this.inkText,
    required this.textSecondary,
    required this.textMuted,
    required this.quranAccent,
    required this.quranAccentBg,
    required this.hadithAccent,
    required this.hadithAccentBg,
    required this.duasAccent,
    required this.duasAccentBg,
    required this.hijriAccent,
    required this.hijriAccentBg,
    required this.worshipAccent,
    required this.worshipAccentBg,
    required this.toolsAccent,
    required this.toolsAccentBg,
    required this.success,
    required this.error,
    required this.boyAccent,
    required this.boyAccentBg,
    required this.girlAccent,
    required this.girlAccentBg,
    required this.shadow,
  });

  /// This palette with the "atmosphere" values replaced. Brand colours
  /// (`emeraldInk`, `heroSurface`, module accents, semantic colours) are
  /// deliberately not overridable, so every period still reads as the same app.
  _Palette atmosphere({
    required Color background,
    required Color gradientEnd,
    required Color surface,
    required Color border,
    required Color inkText,
    required Color textSecondary,
    required Color textMuted,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? gold,
    Color? goldLight,
    Color? amber,
    Color? amberDeep,
    Color? shadow,
  }) {
    return _Palette(
      isDark: isDark,
      emeraldInk: emeraldInk,
      emeraldInkDark: emeraldInkDark,
      onEmeraldInk: onEmeraldInk,
      heroSurface: heroSurface,
      onHeroSurface: onHeroSurface,
      heroGradientStart: heroGradientStart,
      heroGradientEnd: heroGradientEnd,
      gold: gold ?? this.gold,
      goldLight: goldLight ?? this.goldLight,
      amber: amber ?? this.amber,
      amberDeep: amberDeep ?? this.amberDeep,
      backgroundGradientStart: background,
      backgroundGradientEnd: gradientEnd,
      background: background,
      surface: surface,
      border: border,
      inkText: inkText,
      textSecondary: textSecondary,
      textMuted: textMuted,
      quranAccent: quranAccent,
      quranAccentBg: quranAccentBg,
      hadithAccent: hadithAccent,
      hadithAccentBg: hadithAccentBg,
      duasAccent: duasAccent,
      duasAccentBg: duasAccentBg,
      hijriAccent: hijriAccent,
      hijriAccentBg: hijriAccentBg,
      worshipAccent: worshipAccent,
      worshipAccentBg: worshipAccentBg,
      toolsAccent: toolsAccent,
      toolsAccentBg: toolsAccentBg,
      success: success,
      error: error,
      boyAccent: boyAccent,
      boyAccentBg: boyAccentBg,
      girlAccent: girlAccent,
      girlAccentBg: girlAccentBg,
      shadow: shadow ?? this.shadow,
    );
  }

  static final _dhuhr = light.atmosphere(
    // Bright day: today's Light with a clear midday-teal hero.
    background: light.background,
    gradientEnd: light.backgroundGradientEnd,
    surface: light.surface,
    border: light.border,
    inkText: light.inkText,
    textSecondary: light.textSecondary,
    textMuted: light.textMuted,
    heroGradientStart: const Color(0xFF17607A),
    heroGradientEnd: const Color(0xFF3E97AB),
  );

  static final _fajr = dark.atmosphere(
    // Pre-dawn: indigo night with a faint violet glow on the horizon.
    heroGradientStart: const Color(0xFF1E2F52),
    heroGradientEnd: const Color(0xFFB9765A),
    background: const Color(0xFF151828),
    gradientEnd: const Color(0xFF272541),
    surface: const Color(0xFF1E2236),
    border: const Color(0xFF30364D),
    inkText: const Color(0xFFF0EEF4),
    textSecondary: const Color(0xFFB9BDD0),
    textMuted: const Color(0xFF8189A3),
    amber: const Color(0xFFE8A066),
  );

  static final _sunrise = light.atmosphere(
    // Soft peach morning light.
    heroGradientStart: const Color(0xFF4A3558),
    heroGradientEnd: const Color(0xFFC97A52),
    background: const Color(0xFFFFF6EC),
    gradientEnd: const Color(0xFFFBE4D0),
    surface: const Color(0xFFFFFCF8),
    border: const Color(0xFFEBD8C6),
    inkText: const Color(0xFF2A1E18),
    textSecondary: const Color(0xFF665244),
    textMuted: const Color(0xFFA08C7C),
    goldLight: const Color(0xFFFAE6CF),
  );

  static final _asr = light.atmosphere(
    // Golden afternoon: still bright, leaning toward evening.
    heroGradientStart: const Color(0xFF6B4A1A),
    heroGradientEnd: const Color(0xFFB07C24),
    background: const Color(0xFFFBF3DF),
    gradientEnd: const Color(0xFFF1DFB5),
    surface: const Color(0xFFFFFCF2),
    border: const Color(0xFFE4D2A4),
    inkText: const Color(0xFF2A2210),
    textSecondary: const Color(0xFF5A4F34),
    textMuted: const Color(0xFF978B68),
    gold: const Color(0xFFBE9540),
    goldLight: const Color(0xFFF3E4C0),
  );

  static final _maghrib = light.atmosphere(
    // Sunset: amber and terracotta warmth on a light ground.
    heroGradientStart: const Color(0xFF34204A),
    heroGradientEnd: const Color(0xFFC85F3A),
    background: const Color(0xFFFFEFDB),
    gradientEnd: const Color(0xFFF5CFA6),
    surface: const Color(0xFFFFF8EE),
    border: const Color(0xFFEBC79B),
    inkText: const Color(0xFF33190F),
    textSecondary: const Color(0xFF6B422B),
    textMuted: const Color(0xFFA67A5E),
    gold: const Color(0xFFB98235),
    goldLight: const Color(0xFFF7DEBB),
    amber: const Color(0xFFD9732B),
    amberDeep: const Color(0xFFB4551A),
  );

  static final _isha = dark.atmosphere(
    // Night: today's Dark, nudged a little cooler.
    heroGradientStart: const Color(0xFF0B1B2B),
    heroGradientEnd: const Color(0xFF1C3550),
    background: const Color(0xFF10131C),
    gradientEnd: const Color(0xFF181C28),
    surface: const Color(0xFF191D2A),
    border: const Color(0xFF282D3D),
    inkText: const Color(0xFFF2F0E8),
    textSecondary: const Color(0xFFB8BCC8),
    textMuted: const Color(0xFF7F8494),
  );

  static _Palette forVariant(ThemeVariant variant) => switch (variant) {
    ThemeVariant.light => light,
    ThemeVariant.dhuhr => _dhuhr,
    ThemeVariant.dark => dark,
    ThemeVariant.fajr => _fajr,
    ThemeVariant.sunrise => _sunrise,
    ThemeVariant.asr => _asr,
    ThemeVariant.maghrib => _maghrib,
    ThemeVariant.isha => _isha,
  };

  static const light = _Palette(
    isDark: false,
    emeraldInk: Color(0xFFF08232),
    emeraldInkDark: Color(0xFFC96A2E),
    onEmeraldInk: Color(0xFFFCFBF4),
    heroSurface: Color(0xFF1A1A1A),
    onHeroSurface: Color(0xFFFCFBF4),
    gold: Color(0xFFC9A25E),
    goldLight: Color(0xFFF3E7D0),
    amber: Color(0xFFDD8A3E),
    amberDeep: Color(0xFFB96A2A),
    backgroundGradientStart: Color(0xFFFCFBF4),
    backgroundGradientEnd: Color(0xFFF3EDDD),
    background: Color(0xFFFCFBF4),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE7E1D0),
    inkText: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5C5C5C),
    textMuted: Color(0xFF9E9A8F),
    quranAccent: Color(0xFF4F6B4A),
    quranAccentBg: Color(0xFFE3EAD9),
    hadithAccent: Color(0xFF7A3B2E),
    hadithAccentBg: Color(0xFFF2E2DB),
    duasAccent: Color(0xFF9C7A35),
    duasAccentBg: Color(0xFFF3E7D0),
    hijriAccent: Color(0xFF2F6B64),
    hijriAccentBg: Color(0xFFDCEAE7),
    worshipAccent: Color(0xFFC96A2E),
    worshipAccentBg: Color(0xFFF7E0C9),
    toolsAccent: Color(0xFF6B5B45),
    toolsAccentBg: Color(0xFFEDE6D8),
    success: Color(0xFF3F7D4A),
    error: Color(0xFFAE4438),
    boyAccent: Color(0xFF4C7593),
    boyAccentBg: Color(0xFFE1EAF0),
    girlAccent: Color(0xFFB05C78),
    girlAccentBg: Color(0xFFF4E1E7),
    shadow: Color(0x14000000),
  );

  /// Dark keeps the same hue families, moved to a near-black ink-green
  /// ground: accents lift so they read against it, accent *backgrounds* drop
  /// to deep tints of the same hue, and text steps down through the same
  /// three levels of emphasis as Light.
  static const dark = _Palette(
    isDark: true,
    emeraldInk: Color(0xFFF2955A),
    emeraldInkDark: Color(0xFF8C4A1E),
    onEmeraldInk: Color(0xFF1A1A1A),
    heroSurface: Color(0xFF262626),
    onHeroSurface: Color(0xFFFCFBF4),
    gold: Color(0xFFD9B36B),
    goldLight: Color(0xFFF0E3C9),
    amber: Color(0xFFE39A55),
    amberDeep: Color(0xFFC97C38),
    backgroundGradientStart: Color(0xFF141414),
    backgroundGradientEnd: Color(0xFF1C1C1C),
    background: Color(0xFF141414),
    surface: Color(0xFF1F1F1F),
    border: Color(0xFF2E2E2E),
    inkText: Color(0xFFF2F0E8),
    textSecondary: Color(0xFFB8B8B8),
    textMuted: Color(0xFF808080),
    quranAccent: Color(0xFF8FAE7E),
    quranAccentBg: Color(0xFF223026),
    hadithAccent: Color(0xFFC89684),
    hadithAccentBg: Color(0xFF33231F),
    duasAccent: Color(0xFFD8B368),
    duasAccentBg: Color(0xFF332C1E),
    hijriAccent: Color(0xFF74B7AC),
    hijriAccentBg: Color(0xFF17302C),
    worshipAccent: Color(0xFFE0985C),
    worshipAccentBg: Color(0xFF3A2818),
    toolsAccent: Color(0xFFBFA98C),
    toolsAccentBg: Color(0xFF2E2A22),
    success: Color(0xFF63B36F),
    error: Color(0xFFE0796A),
    boyAccent: Color(0xFF7FAECB),
    boyAccentBg: Color(0xFF1E2A33),
    girlAccent: Color(0xFFD08FA6),
    girlAccentBg: Color(0xFF33222A),
    shadow: Color(0x33000000),
  );
}
