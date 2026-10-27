import 'package:deen_companion/features/favorites/domain/entities/favorite_item.dart';
import 'package:deen_companion/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Favourites that start empty and record toggles, with no storage behind them.
class FakeFavorites extends FavoritesNotifier {
  final toggled = <FavoriteItem>[];

  @override
  Stream<List<FavoriteItem>> build() => Stream.value(const []);

  @override
  Future<void> toggle(FavoriteItem item) async => toggled.add(item);
}

FavoriteItem favoriteFixture() => FavoriteItem(
  id: 'surah:2',
  type: FavoriteContentType.surah,
  referenceId: '2',
  title: 'Al-Baqarah',
  subtitle: 'Mishary Rashid Alafasy',
  route: '/quran',
  savedAt: DateTime(2026),
);

/// Pumps [child] on an iPhone-sized screen with the providers the player
/// widgets read. Returns the favourites fake, to check taps on the heart.
Future<FakeFavorites> pumpPlayer(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final favorites = FakeFavorites();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [favoritesNotifierProvider.overrideWith(() => favorites)],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
  return favorites;
}
