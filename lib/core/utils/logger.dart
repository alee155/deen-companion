import 'package:logger/logger.dart';
import '../config/flavor_config.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, colors: true, printEmojis: false),
  );

  static void d(String message) {
    if (FlavorConfig.instance.enableLogging) _logger.d(message);
  }

  static void i(String message) {
    if (FlavorConfig.instance.enableLogging) _logger.i(message);
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
