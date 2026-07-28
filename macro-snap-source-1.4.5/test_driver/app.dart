import 'package:flutter_driver/driver_extension.dart';
import 'package:macro_snap/main.dart' as app;

/// Flutter Driver instrumented entry point.
///
/// Run with:
///   flutter drive --target=test_driver/app.dart
///
/// This enables the driver extension so that test_driver/app_test.dart
/// can connect and drive the app programmatically.
void main() {
  enableFlutterDriverExtension();
  app.main();
}
