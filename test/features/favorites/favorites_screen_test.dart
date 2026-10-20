import 'package:deen_companion/features/favorites/data/datasources/favorites_local_datasource.dart';
import 'package:deen_companion/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:deen_companion/features/favorites/domain/entities/favorite_item.dart';
import 'package:deen_companion/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:deen_companion/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_storage_service.dart';

FavoriteItem fav(FavoriteContentType type, String ref, {int day = 1}) =>
    FavoriteItem(
      id: FavoriteItem.buildId(type, ref),
      type: type,
      referenceId: ref,
      title: 'Title $ref',
      route: '/r/$ref',
      savedAt: DateTime.utc(2024, 1, day),
    );

Future<ProviderContainer> pump(
  WidgetTester tester,
  List<FavoriteItem> seed,
) async {
  final storage = InMemoryStorageService();
  final repo = FavoritesRepositoryImpl(FavoritesLocalDataSourceImpl(storage));
  for (final f in seed) {
    await repo.toggle(f);
  }
  final container = ProviderContainer(
    overrides: [favoritesRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(1125, 2436);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(home: FavoritesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('empty state invites the user to explore', (tester) async {
    await pump(tester, []);
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows totals, category chips and grouped cards', (tester) async {
    await pump(tester, [
      fav(FavoriteContentType.surah, 'a'),
      fav(FavoriteContentType.surah, 'b', day: 2),
      fav(FavoriteContentType.dua, 'c'),
    ]);
    expect(find.text('3 saved'), findsOneWidget);
    expect(find.text('2 categories'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    // Headings and chips both carry the category name.
    expect(find.text('Surahs'), findsNWidgets(2));
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Title c'), findsOneWidget);
  });

  testWidgets('a category chip narrows the list', (tester) async {
    await pump(tester, [
      fav(FavoriteContentType.surah, 'a'),
      fav(FavoriteContentType.dua, 'c'),
    ]);
    await tester.tap(find.text('Duas').first);
    await tester.pumpAndSettle();
    expect(find.text('Title c'), findsOneWidget);
    expect(find.text('Title a'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('search filters, shows no-matches and can be cleared', (
    tester,
  ) async {
    await pump(tester, [
      fav(FavoriteContentType.surah, 'a'),
      fav(FavoriteContentType.dua, 'c'),
    ]);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsNothing);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('removing the last item of a category drops back to All', (
    tester,
  ) async {
    final c = await pump(tester, [
      fav(FavoriteContentType.surah, 'a'),
      fav(FavoriteContentType.dua, 'c'),
    ]);
    await tester.tap(find.text('Duas').first);
    await tester.pumpAndSettle();
    expect(c.read(favoritesTypeFilterProvider), FavoriteContentType.dua);

    await c.read(favoritesNotifierProvider.notifier).remove('dua:c');
    await tester.pumpAndSettle();
    expect(c.read(favoritesTypeFilterProvider), isNull);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('swipe removes with an undo that brings it back', (tester) async {
    await pump(tester, [
      fav(FavoriteContentType.surah, 'a'),
      fav(FavoriteContentType.dua, 'c'),
    ]);
    await tester.drag(find.text('Title a'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsNothing);
    expect(find.text('Removed "Title a"'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsOneWidget);
  });
}
