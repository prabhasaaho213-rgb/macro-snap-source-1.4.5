import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/core/theme.dart';

/// Pins the bundled-font setup: the theme must resolve to the local 'Inter'
/// family (no runtime fetch) and the asset must be a valid TrueType font.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme resolves the bundled Inter family in both modes', () {
    expect(MacroSnapTheme.light.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(MacroSnapTheme.light.textTheme.displayLarge?.fontFamily, 'Inter');
    expect(MacroSnapTheme.dark.textTheme.bodyLarge?.fontFamily, 'Inter');
    expect(MacroSnapTheme.dark.textTheme.titleMedium?.fontFamily, 'Inter');
  });

  test('bundled Inter asset is a valid TrueType font', () async {
    final data = await rootBundle.load('assets/fonts/Inter.ttf');
    expect(data.lengthInBytes, greaterThan(500000));
    final bytes = data.buffer.asUint8List();
    // TrueType sfnt header: 0x00010000.
    expect(bytes.sublist(0, 4), [0x00, 0x01, 0x00, 0x00]);
  });
}
