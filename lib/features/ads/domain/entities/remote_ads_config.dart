/// One ad type as the ads service resolved it: the server has already folded
/// the global, app, platform and per-unit switches into [enabled].
class AdSlotConfig {
  final bool enabled;
  final String? unitId;

  const AdSlotConfig({required this.enabled, this.unitId});

  static const off = AdSlotConfig(enabled: false);

  /// Shown only when switched on and given a real unit id.
  bool get usable => enabled && unitId != null && unitId!.trim().isNotEmpty;

  factory AdSlotConfig.fromJson(Object? json) {
    if (json is! Map) return off;
    final id = json['unit_id'];
    return AdSlotConfig(
      enabled: json['enabled'] == true,
      unitId: id is String ? id : null,
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'unit_id': unitId};
}

/// What `GET /v1/apps/{appKey}/ads?platform=` returns. The safe default is
/// [off]: with no config the app shows no ads.
class RemoteAdsConfig {
  final bool adsEnabled;
  final AdSlotConfig banner;
  final AdSlotConfig interstitial;
  final AdSlotConfig appOpen;
  final int configVersion;
  final int ttlSeconds;

  const RemoteAdsConfig({
    required this.adsEnabled,
    required this.banner,
    required this.interstitial,
    required this.appOpen,
    this.configVersion = 0,
    this.ttlSeconds = defaultTtlSeconds,
  });

  static const defaultTtlSeconds = 3600;

  static const off = RemoteAdsConfig(
    adsEnabled: false,
    banner: AdSlotConfig.off,
    interstitial: AdSlotConfig.off,
    appOpen: AdSlotConfig.off,
  );

  factory RemoteAdsConfig.fromJson(Map<String, dynamic> json) {
    final ads = json['ads'];
    final slots = ads is Map ? ads : const {};
    final ttl = json['ttl_seconds'];
    final version = json['config_version'];
    return RemoteAdsConfig(
      adsEnabled: json['ads_enabled'] == true,
      banner: AdSlotConfig.fromJson(slots['banner']),
      interstitial: AdSlotConfig.fromJson(slots['interstitial']),
      appOpen: AdSlotConfig.fromJson(slots['app_open']),
      configVersion: version is int ? version : 0,
      ttlSeconds: ttl is int && ttl > 0 ? ttl : defaultTtlSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'ads_enabled': adsEnabled,
    'ads': {
      'banner': banner.toJson(),
      'interstitial': interstitial.toJson(),
      'app_open': appOpen.toJson(),
    },
    'config_version': configVersion,
    'ttl_seconds': ttlSeconds,
  };
}
