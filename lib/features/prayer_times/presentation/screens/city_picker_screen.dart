import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/city_search_provider.dart';
import '../providers/manual_city_provider.dart';

/// Pick a city for prayer times instead of sharing the device location.
/// Pops with `true` once a choice is made.
class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({super.key});

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useDeviceLocation() async {
    await ref.read(manualCityProvider.notifier).clear();
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(citySearchProvider);
    final chosen = ref.watch(manualCityProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.inkText,
        title: Text(
          'Choose a city',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prayer times are calculated for the city you pick. Only the '
              'city’s coordinates are used.',
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: ref.read(citySearchProvider.notifier).onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search a city, e.g. Lahore',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide(color: AppColors.borderWarm),
                ),
              ),
            ),
            if (chosen != null) ...[
              SizedBox(height: 8.h),
              TextButton.icon(
                onPressed: _useDeviceLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(
                  'Use my device location instead (now: ${chosen.name})',
                ),
              ),
            ],
            SizedBox(height: 8.h),
            Expanded(child: _body(search)),
          ],
        ),
      ),
    );
  }

  Widget _body(CitySearchState s) {
    switch (s.status) {
      case CitySearchStatus.idle:
        return _note('Type at least 2 letters. English names work best.');
      case CitySearchStatus.tooShort:
        return _note('Keep typing…');
      case CitySearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CitySearchStatus.error:
        return Column(
          children: [
            _note(s.message ?? 'Something went wrong.'),
            TextButton(
              onPressed: ref.read(citySearchProvider.notifier).retry,
              child: const Text('Try again'),
            ),
          ],
        );
      case CitySearchStatus.results:
        if (s.cities.isEmpty) {
          return _note('No city found for “${s.query}”. Try another spelling.');
        }
        return ListView.separated(
          itemCount: s.cities.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: AppColors.borderWarm),
          itemBuilder: (context, i) {
            final city = s.cities[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.location_city_rounded,
                color: AppColors.emeraldInk,
              ),
              title: Text(
                city.name,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
              subtitle: Text(
                [
                  if (city.region.isNotEmpty) city.region,
                  city.country,
                ].where((p) => p.isNotEmpty).join(', '),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () async {
                await ref.read(manualCityProvider.notifier).select(city);
                // ignore: use_build_context_synchronously
                if (mounted) context.pop(true);
              },
            );
          },
        );
    }
  }

  Widget _note(String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: 24.h),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
      ),
    ),
  );
}
