import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/ads_config_remote_datasource.dart';
import '../../data/datasources/app_open_ad_datasource.dart';
import '../../data/datasources/banner_ad_datasource.dart';
import '../../data/datasources/interstitial_ad_datasource.dart';
import '../../data/datasources/mobile_ads_initializer.dart';
import '../../data/repositories/ads_repository_impl.dart';
import '../../data/services/ad_unit_resolver.dart';
import '../../data/services/ads_config_store.dart';
import '../../data/services/ads_consent.dart';
import '../../domain/repositories/ads_repository.dart';

final mobileAdsInitializerProvider = Provider<MobileAdsInitializer>((ref) {
  return const MobileAdsInitializer();
});

final bannerAdDataSourceProvider = Provider<BannerAdDataSource>((ref) {
  return const BannerAdDataSource();
});

final interstitialAdDataSourceProvider = Provider<InterstitialAdDataSource>((
  ref,
) {
  return const InterstitialAdDataSource();
});

final appOpenAdDataSourceProvider = Provider<AppOpenAdDataSource>((ref) {
  return const AppOpenAdDataSource();
});

const _honorServer = bool.fromEnvironment('ADS_HONOR_SERVER');

/// The ads service's answer (saved copy first, refetched after its TTL).
final adsConfigStoreProvider = Provider<AdsConfigStore>((ref) {
  return AdsConfigStore(
    remote: AdsConfigRemoteDataSource(),
    storage: ref.watch(localStorageServiceProvider),
    platform: Platform.isIOS ? 'ios' : 'android',
    // Debug builds show Google test ads even while the server has ads off.
    // `--dart-define=ADS_HONOR_SERVER=true` makes debug obey the server too.
    forceTestAds: kDebugMode && !_honorServer,
  );
});

final adsConsentProvider = Provider<AdsConsent>((ref) {
  return const PlatformAdsConsent();
});

/// The centralized real/test/disabled decision maker.
final adUnitResolverProvider = Provider<AdUnitResolver>((ref) {
  final config = ref.watch(adsConfigStoreProvider);
  return AdUnitResolver(() => config.current);
});

/// One repository instance for the whole app lifetime — interstitial and
/// app open ads are inherently app-wide singletons (there is only ever one
/// "currently loaded interstitial"), not something to recreate per screen.
final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  final repository = AdsRepositoryImpl(
    initializer: ref.watch(mobileAdsInitializerProvider),
    adUnitResolver: ref.watch(adUnitResolverProvider),
    config: ref.watch(adsConfigStoreProvider),
    consent: ref.watch(adsConsentProvider),
    bannerDataSource: ref.watch(bannerAdDataSourceProvider),
    interstitialDataSource: ref.watch(interstitialAdDataSourceProvider),
    appOpenDataSource: ref.watch(appOpenAdDataSourceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Runs the Mobile Ads SDK's one-time initialization
/// exactly once for the life of the app. `bootstrap.dart` reads this
/// (fire-and-forget, never awaited against the first frame) so ad loading
/// can start as early as possible without delaying app startup.
final adsInitializationProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(adsRepositoryProvider);
  await repository.initialize();
});
