enum Flavor { dev, prod }

class FlavorConfig {
  final Flavor flavor;
  final bool enableLogging;
  final String ummahApiKey;

  static FlavorConfig? _instance;

  factory FlavorConfig({required Flavor flavor, required bool enableLogging}) {
    _instance ??= FlavorConfig._internal(
      flavor: flavor,
      enableLogging: enableLogging,
      ummahApiKey: const String.fromEnvironment('UMMAH_API_KEY'),
    );
    return _instance!;
  }

  FlavorConfig._internal({
    required this.flavor,
    required this.enableLogging,
    required this.ummahApiKey,
  });

  static FlavorConfig get instance {
    assert(_instance != null, 'FlavorConfig not initialized.');
    return _instance!;
  }

  static bool get isProd => instance.flavor == Flavor.prod;
  static bool get isDev => instance.flavor == Flavor.dev;
}
