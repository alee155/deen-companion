import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/prayer_times_bundle.dart';
import '../../domain/prayer_times_failure.dart';
import 'prayer_times_loader.dart';

enum CitySearchStatus { idle, tooShort, loading, results, error }

@immutable
class CitySearchState {
  final String query;
  final CitySearchStatus status;
  final List<PrayerCity> cities;
  final String? message;

  const CitySearchState({
    this.query = '',
    this.status = CitySearchStatus.idle,
    this.cities = const [],
    this.message,
  });
}

/// Type-ahead city search for people who don't share their location.
/// Debounced, ignores answers to a query that has since changed, and needs
/// at least [minLength] characters (the server expects English names).
class CitySearchController extends AutoDisposeNotifier<CitySearchState> {
  static const minLength = 2;
  static const debounce = Duration(milliseconds: 400);

  Timer? _timer;
  int _latest = 0;

  @override
  CitySearchState build() {
    ref.onDispose(() => _timer?.cancel());
    return const CitySearchState();
  }

  void onQueryChanged(String raw) {
    final query = raw.trim();
    _timer?.cancel();
    final ticket = ++_latest;

    if (query.isEmpty) {
      state = const CitySearchState();
      return;
    }
    if (query.length < minLength) {
      state = CitySearchState(query: query, status: CitySearchStatus.tooShort);
      return;
    }
    state = CitySearchState(query: query, status: CitySearchStatus.loading);
    _timer = Timer(debounce, () => _search(query, ticket));
  }

  Future<void> _search(String query, int ticket) async {
    final result = await ref
        .read(prayerTimesRepositoryProvider)
        .searchCities(query);
    if (ticket != _latest) return; // the user kept typing
    state = result.when(
      success: (cities) => CitySearchState(
        query: query,
        status: CitySearchStatus.results,
        cities: cities,
      ),
      failure: (f) => CitySearchState(
        query: query,
        status: CitySearchStatus.error,
        message: _message(f),
      ),
    );
  }

  /// Search again for the current query (after an error).
  void retry() => onQueryChanged(state.query);

  static String _message(Failure f) =>
      f is PrayerTimesFailure &&
          f.code == PrayerTimesErrorCode.citySearchUnavailable
      ? 'City search isn’t available right now. Try again in a moment.'
      : f.message;
}

final citySearchProvider =
    NotifierProvider.autoDispose<CitySearchController, CitySearchState>(
      CitySearchController.new,
    );
