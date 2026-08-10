import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ad_placement_key.dart';
import '../providers/interstitial_ad_coordinator.dart';

/// Wraps any tappable widget so its [onTap] runs through the shared
/// interstitial odd/even rule for [placement], instead of navigating (or
/// running whatever [onTap] does) directly.
///
/// This is the drop-in counterpart to [BannerAdWidget] for interstitials:
/// a list tile, card, or button that currently does
/// `onTap: () => context.push(route)` becomes
/// `AdAwareTap(placement: ..., onTap: () => context.push(route), child: ...)`
/// and picks up frequency-capped interstitials for free.
class AdAwareTap extends ConsumerWidget {
  const AdAwareTap({
    super.key,
    required this.placement,
    required this.onTap,
    required this.child,
    this.borderRadius,
  });

  final AdPlacementKey placement;
  final VoidCallback onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: () {
        ref
            .read(interstitialAdCoordinatorProvider)
            .showThenRun(placement: placement, action: onTap);
      },
      child: child,
    );
  }
}
