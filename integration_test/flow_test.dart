import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:macro_snap/app.dart';
import 'package:macro_snap/core/theme.dart';
import 'package:macro_snap/models/meal_record.dart';
import 'package:macro_snap/services/gemini_service.dart';
import 'package:macro_snap/services/meal_store.dart';
import 'package:macro_snap/screens/result_screen.dart';
import 'package:macro_snap/screens/main_shell.dart';

/// Creates a minimal valid PNG file (1×1 red pixel) for testing.
///
/// PNG is preferred over JPEG because it's simpler to craft valid headers
/// and Flutter's Image.file widget decodes it reliably.
Future<String> createTestImage({String? path}) async {
  final file = File(path ?? '${Directory.systemTemp.path}/test_food_${DateTime.now().millisecondsSinceEpoch}.png');

  // Minimal valid PNG: signature + IHDR (1×1 RGB) + IDAT (raw pixel) + IEND
  // PNG signature
  final signature = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk: width=1, height=1, bit_depth=8, color_type=2 (RGB),
  // compression=0, filter=0, interlace=0
  final ihdrData = Uint8List.fromList([
    0x00, 0x00, 0x00, 0x01, // width
    0x00, 0x00, 0x00, 0x01, // height
    0x08, 0x02, 0x00, 0x00, 0x00, // bit_depth=8, color_type=2 (RGB)
  ]);
  final ihdrCrc = _crc32(ihdrData);
  final ihdr = Uint8List(12 + ihdrData.length);
  _writeInt32(ihdr, 0, ihdrData.length);          // length
  ihdr[4] = 0x49; ihdr[5] = 0x48; ihdr[6] = 0x44; ihdr[7] = 0x52; // 'IHDR'
  ihdr.setRange(8, 8 + ihdrData.length, ihdrData);
  _writeInt32(ihdr, 8 + ihdrData.length, ihdrCrc);

  // IDAT chunk: zlib-compressed row (filter byte 0 + RGB 0,0,0)
  // Zlib: 0x78 0x01 (deflate, no compression) ... 0x?? 0x?? (adler32)
  // For a 1×1 RGB image: filter=0x00, pixel=0x00 0x00 0x00
  // Pre-computed zlib stream for this case:
  final idatData = Uint8List.fromList([
    0x78, 0x01, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01,
  ]);
  final idatCrc = _crc32(idatData);
  final idat = Uint8List(12 + idatData.length);
  _writeInt32(idat, 0, idatData.length);
  idat[4] = 0x49; idat[5] = 0x44; idat[6] = 0x41; idat[7] = 0x54; // 'IDAT'
  idat.setRange(8, 8 + idatData.length, idatData);
  _writeInt32(idat, 8 + idatData.length, idatCrc);

  // IEND chunk
  final iendData = Uint8List(0);
  final iendCrc = _crc32(iendData);
  final iend = Uint8List(12);
  _writeInt32(iend, 0, 0);
  iend[4] = 0x49; iend[5] = 0x45; iend[6] = 0x4E; iend[7] = 0x44; // 'IEND'
  _writeInt32(iend, 8, iendCrc);

  // Combine everything
  final bytes = Uint8List(signature.length + ihdr.length + idat.length + iend.length);
  bytes.setRange(0, signature.length, signature);
  bytes.setRange(signature.length, signature.length + ihdr.length, ihdr);
  bytes.setRange(signature.length + ihdr.length, signature.length + ihdr.length + idat.length, idat);
  bytes.setRange(signature.length + ihdr.length + idat.length, bytes.length, iend);

  await file.writeAsBytes(bytes);
  return file.path;
}

void _writeInt32(Uint8List list, int offset, int value) {
  list[offset] = (value >> 24) & 0xFF;
  list[offset + 1] = (value >> 16) & 0xFF;
  list[offset + 2] = (value >> 8) & 0xFF;
  list[offset + 3] = value & 0xFF;
}

int _crc32(Uint8List data) {
  // Simple CRC-32 / IEEE (used in PNG)
  const table = _crc32Table;
  int crc = 0xFFFFFFFF;
  for (int i = 0; i < data.length; i++) {
    crc = table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

// Pre-computed CRC-32 table
const List<int> _crc32Table = [
  0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA,
  0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
  0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
  0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
  0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE,
  0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
  0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC,
  0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
  0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
  0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
  0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940,
  0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
  0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116,
  0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
  0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
  0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
  0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A,
  0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
  0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818,
  0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
  0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
  0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
  0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C,
  0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
  0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2,
  0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
  0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
  0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
  0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086,
  0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
  0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4,
  0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
  0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
  0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
  0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8,
  0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
  0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE,
  0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
  0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
  0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
  0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252,
  0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
  0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60,
  0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
  0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
  0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
  0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04,
  0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
  0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A,
  0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
  0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
  0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
  0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E,
  0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
  0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C,
  0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
  0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
  0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
  0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0,
  0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
  0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6,
  0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
  0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
  0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D,
];

/// Returns a predefined [NutritionResult] for testing the result screen flow.
NutritionResult makeMockResult() {
  return const NutritionResult(
    dishes: [
      DishItem(
        name: 'Test Breakfast',
        portionDescription: '2 eggs, toast',
        caloriesPer100g: 200,
        proteinPer100g: 15.0,
        carbsPer100g: 25.0,
        fatsPer100g: 8.0,
        fiberPer100g: 2.0,
        sugarPer100g: 3.0,
        suitableFor: 'both',
      ),
    ],
    description: 'Integration test analysis',
    confidence: 0.95,
    grams: 100,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─── SharedPreferences must be mocked before any widget is pumped ─────
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'name': 'TestUser',
      'phone': '9999999999',
      'subscribed': false,
      'server_url': '',
      'onboarding_done': true,
    });
  });

  group('Full App Flow: Scan → Results → Log → Home', () {
    late String testImagePath;

    setUp(() async {
      testImagePath = await createTestImage();
    });

    tearDown(() {
      try {
        final f = File(testImagePath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    });

    // ═══════════════════════════════════════════════════════════════════
    // TEST 1: Scan screen renders its core UI elements
    // ═══════════════════════════════════════════════════════════════════
    testWidgets('1. Scan screen renders core UI elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MacroSnapApp());
      await tester.pump();

      // Navigate to Scan tab via bottom nav — MainShell shows Home, Scan, Habits
      // Scan tab has Icons.camera_alt_rounded (the capture button)
      final scanNav = find.byIcon(Icons.camera_alt_rounded);
      // On emulators without a real camera, the scan screen enters error state
      // and shows a different layout. We only test the gallery button which
      // appears in both states.
      await tester.tap(scanNav.last);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The gallery picker button should always be present
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);

    });

    // ═══════════════════════════════════════════════════════════════════
    // TEST 2: Result screen → Log Meal → meal stored in MealStore
    // ═══════════════════════════════════════════════════════════════════
    testWidgets('2. Result screen logs meal and stores it in MealStore',
        (WidgetTester tester) async {
      // Set mock result BEFORE pumping the widget
      GeminiService.mockResult = makeMockResult();

      await tester.pumpWidget(
        MaterialApp(
          theme: MacroSnapTheme.light,
          darkTheme: MacroSnapTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(imagePath: testImagePath),
                      ),
                    );
                  },
                  child: const Text('Open Result'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the button to navigate to ResultScreen
      await tester.tap(find.text('Open Result'));
      await tester.pump();

      // Wait for analysis (mock returns immediately) + animation controllers
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The mock result has 200 cal/100g × 100g = 200 calories → "200" shown
      expect(find.text('200'), findsAtLeast(1));

      // AI breakdown section should show the dish name
      expect(find.text('Test Breakfast'), findsAtLeast(1));

      // "Log This Meal" button should be visible
      expect(find.text('Log This Meal'), findsOneWidget);

      // Tap Log This Meal
      await tester.tap(find.text('Log This Meal'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // After logging, ResultScreen pops to the initial button screen.
      // Verify the meal was actually stored in MealStore
      final todayMeals = MealStore.instance.todayMeals;
      expect(todayMeals.any((m) => m.name == 'Test Breakfast'), isTrue);

      // Verify we're back on the initial route
      expect(find.text('Open Result'), findsOneWidget);

      // Clean up
      GeminiService.mockResult = null;
    });

    // ═══════════════════════════════════════════════════════════════════
    // TEST 3: Home screen displays logged meals in recent section
    // ═══════════════════════════════════════════════════════════════════
    testWidgets('3. Home screen shows logged meals after data added',
        (WidgetTester tester) async {
      // Pre-populate meal data via runAsync to let platform channels settle
      await tester.runAsync(() async {
        await MealStore.instance.add(MealRecord(
          id: 'e2e-test-meal-001',
          date: DateTime.now(),
          name: 'Integration Test Meal',
          category: '',
          calories: 650,
          protein: 35,
          carbs: 70,
          fats: 22,
          fiber: 8,
          serving: 'Full test serving',
        ));
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: MacroSnapTheme.light,
          darkTheme: MacroSnapTheme.dark,
          home: const MainShell(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Navigate to Home tab
      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The meal name should appear somewhere in the home screen
      expect(find.text('Integration Test Meal'), findsOneWidget);

      // Calorie value should be visible
      expect(find.text('650'), findsAtLeast(1));
    });

    // ═══════════════════════════════════════════════════════════════════
    // TEST 4: Error state shows when analysis fails
    // ═══════════════════════════════════════════════════════════════════
    testWidgets('4. Result screen shows error when analysis fails',
        (WidgetTester tester) async {
      // Ensure the server URL is empty so Gemini is skipped, forcing
      // the local analyzer fallback which will fail on a test image.
      GeminiService.mockResult = null;

      await tester.pumpWidget(
        MaterialApp(
          theme: MacroSnapTheme.light,
          darkTheme: MacroSnapTheme.dark,
          home: ResultScreen(imagePath: testImagePath),
        ),
      );
      await tester.pump();

      // Wait for analysis to fail (server URL empty → local analyzer → error)
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should show an error state — either "Analysis Failed" title
      // (from _buildError) or the error screen with an error icon.
      expect(
        find.text('Analysis Failed'),
        findsOneWidget,
      );
    });
  });
}
