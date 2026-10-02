/// Single place to swap the splash identity. Replace [logoAsset] with the
/// final app icon (keep it square-ish; transparent or light background).
class SplashBranding {
  SplashBranding._();

  static const String logoAsset = 'assets/images/deen_comp.png';
  static const String bismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
  static const String tagline = 'Your daily companion in faith';

  /// Full animation timeline, including the closing hold. Navigation never
  /// happens before this completes (or [reducedMotionHold] if the OS asks
  /// for no animations).
  static const Duration timeline = Duration(milliseconds: 2300);
  static const Duration reducedMotionHold = Duration(milliseconds: 700);
}
