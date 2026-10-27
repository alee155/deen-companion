import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../connectivity/presentation/providers/connectivity_providers.dart';
import '../usecase/usecase.dart';

/// Base class implementing the "cache-first, silent background refresh"
/// pattern used across the app's read-mostly screens (Surah list, Hadith
/// collections, Duas, Zakat info, prayer times, ...).
///
/// Behavior:
/// 1. On first watch, synchronously emit whatever is already cached (if
///    anything) — the UI shows real content immediately, no shimmer.
/// 2. Kick off a network refresh in the background.
/// 3. Only emit again if the freshly-fetched data is actually different
///    from what's already on screen. Because this is a [Stream] (not a
///    re-invoked Future), Riverpod does not reset the provider to
///    [AsyncLoading] between the two emissions — the previous value stays
///    visible the whole time, so the shimmer never reappears once the
///    first data (cached or fresh) has been shown.
///
/// 4. If that refresh failed, try again once the connection comes back
///    (see [connectionRestoredProvider]), so a screen opened offline fills in
///    by itself instead of staying stale until the user leaves and returns.
///
/// Subclasses only need to say *how* to read the cache and *how* to fetch
/// + cache fresh data; every screen gets the same guarantee instead of
/// each feature hand-rolling (and subtly diverging on) this logic.
abstract class CacheFirstStreamNotifier<T> extends StreamNotifier<T> {
  /// The last refresh failed, so there is something to retry on reconnect.
  bool _refreshFailed = false;

  /// Synchronous read of whatever is currently cached, or null if nothing
  /// has ever been cached yet.
  T? readCache();

  /// Fetch fresh data from the network and persist it to the cache.
  /// Implementations typically delegate straight to a repository method
  /// that already does its own cache-write + TTL bookkeeping.
  Future<Result<T>> fetchFresh();

  @override
  Stream<T> build() async* {
    ref.listen(connectionRestoredProvider, (_, _) {
      if (_refreshFailed) ref.invalidateSelf();
    });
    _refreshFailed = false;

    final cached = readCache();
    if (cached != null) yield cached;

    final result = await fetchFresh();
    final fresh = result.when(
      success: (data) => data,
      failure: (failure) {
        _refreshFailed = true;
        // No cache to fall back on — this is a real, user-visible error.
        if (cached == null) throw failure;
        // Otherwise: keep showing the cached data quietly. A transient
        // network hiccup shouldn't yank content off the screen.
        return null;
      },
    );

    if (fresh != null && fresh != cached) yield fresh;
  }
}

/// Same contract as [CacheFirstStreamNotifier], but for `.family` providers
/// keyed by an argument (e.g. a Juz number, a Mushaf page, a collection
/// key).
abstract class FamilyCacheFirstStreamNotifier<T, Arg>
    extends FamilyStreamNotifier<T, Arg> {
  bool _refreshFailed = false;

  T? readCache(Arg arg);

  Future<Result<T>> fetchFresh(Arg arg);

  @override
  Stream<T> build(Arg arg) async* {
    ref.listen(connectionRestoredProvider, (_, _) {
      if (_refreshFailed) ref.invalidateSelf();
    });
    _refreshFailed = false;

    final cached = readCache(arg);
    if (cached != null) yield cached;

    final result = await fetchFresh(arg);
    final fresh = result.when(
      success: (data) => data,
      failure: (failure) {
        _refreshFailed = true;
        if (cached == null) throw failure;
        return null;
      },
    );

    if (fresh != null && fresh != cached) yield fresh;
  }
}
