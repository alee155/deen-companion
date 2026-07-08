import 'bootstrap.dart';
import 'core/config/flavor_config.dart';

void main() {
  FlavorConfig(flavor: Flavor.prod, enableLogging: false);
  bootstrap();
}
