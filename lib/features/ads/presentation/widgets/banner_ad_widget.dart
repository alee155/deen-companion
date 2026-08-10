import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/ad_load_status.dart';
import '../../domain/entities/banner_ad_handle.dart';
import '../providers/ads_providers.dart';

/// Drop this in wherever a screen wants a banner ad — it manages its own
/// load, loading placeholder, failure state, and disposal, so call sites
/// never touch the ads SDK directly.
///
/// One [BannerAdWidget] instance owns exactly one [BannerAdHandle]: since
/// each instance loads and disposes its own ad independently, there's no
/// possibility of two widgets fighting over — or accidentally disposing —
/// the same underlying ad.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key, this.margin});

  /// Optional spacing around the ad slot. Applied to both the loading
  /// placeholder and the loaded ad, so a screen doesn't get a layout jump
  /// once loading finishes.
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAdHandle? _handle;
  AdLoadStatus _status = AdLoadStatus.initial;

  @override
  void initState() {
    super.initState();
    // Deferred to the post-frame callback rather than called straight from
    // initState: MediaQuery (needed to size an adaptive banner) isn't
    // guaranteed to be available yet, and this keeps ad loading from ever
    // competing with this widget's own first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _status = AdLoadStatus.loading);

    final width = MediaQuery.sizeOf(context).width;
    final repository = ref.read(adsRepositoryProvider);
    final handle = await repository.loadBanner(width: width);

    if (!mounted) {
      // The screen was popped while the ad was still loading — the ad
      // must still be disposed even though nobody will ever render it.
      handle?.dispose();
      return;
    }

    setState(() {
      _handle = handle;
      _status = handle == null ? AdLoadStatus.failed : AdLoadStatus.loaded;
    });
  }

  @override
  void dispose() {
    _handle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case AdLoadStatus.initial:
      case AdLoadStatus.loading:
        return Padding(
          padding: widget.margin ?? EdgeInsets.zero,
          child: const _BannerPlaceholder(),
        );

      case AdLoadStatus.failed:
        // Collapses to nothing — reserving dead space for an ad that
        // never arrived looks like a broken layout, and there's nothing
        // useful to put there instead.
        return const SizedBox.shrink();

      case AdLoadStatus.loaded:
        final handle = _handle!;
        return Container(
          margin: widget.margin,
          width: handle.size.width.toDouble(),
          height: handle.size.height.toDouble(),
          alignment: Alignment.center,
          child: AdWidget(ad: handle.ad),
        );
    }
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    // A fixed, modest height keeps the placeholder from causing its own
    // layout jump once the real (adaptive-height) banner arrives — most
    // adaptive banners on a phone-width screen land close to this height.
    return const ShimmerBox(
      width: double.infinity,
      height: 50,
      borderRadius: 8,
    );
  }
}
