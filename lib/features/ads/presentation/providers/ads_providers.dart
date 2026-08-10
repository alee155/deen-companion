import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/app_open_ad_datasource.dart';
import '../../data/datasources/banner_ad_datasource.dart';
import '../../data/datasources/interstitial_ad_datasource.dart';
import '../../data/datasources/mobile_ads_initializer.dart';
import '../../data/repositories/ads_repository_impl.dart';
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

/// One repository instance for the whole app lifetime — interstitial and
/// app open ads are inherently app-wide singletons (there is only ever one
/// "currently loaded interstitial"), not something to recreate per screen.
final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  final repository = AdsRepositoryImpl(
    initializer: ref.watch(mobileAdsInitializerProvider),
    bannerDataSource: ref.watch(bannerAdDataSourceProvider),
    interstitialDataSource: ref.watch(interstitialAdDataSourceProvider),
    appOpenDataSource: ref.watch(appOpenAdDataSourceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Runs the Mobile Ads SDK's one-time initialization exactly once for the
/// life of the app. `bootstrap.dart` reads this (fire-and-forget, never
/// awaited against the first frame) so ad loading can start as early as
/// possible without delaying app startup.
final adsInitializationProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(adsRepositoryProvider);
  await repository.initialize();
  // Warm the first interstitial as soon as the SDK is ready — the first
  // placement a user reaches shouldn't have to wait on a cold load.
  unawaited(repository.preloadInterstitial());
});
