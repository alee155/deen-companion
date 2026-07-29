import 'bootstrap.dart';
import 'core/config/flavor_config.dart';

void main() {
  FlavorConfig(flavor: Flavor.dev, enableLogging: true);
  bootstrap();
}
