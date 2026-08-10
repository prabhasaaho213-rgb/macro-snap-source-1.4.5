import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/models/diet_profile.dart';
import 'package:macro_snap/widgets/mascot.dart';

/// Pins the mascot character: it must render cleanly (no exceptions) in every
/// mood and drive its look from a saved profile (gender + skin tone + build).
/// The idle animation repeats forever like StreakFlame, so the test uses fixed
/// pumps and unmounts the widget before it ends.
void main() {
  testWidgets('MascotWidget renders every mood without errors', (tester) async {
    for (final mood in MascotMood.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: MascotWidget(size: 100, mood: mood)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.takeException(),
        isNull,
        reason: 'mood $mood must render cleanly',
      );
    }
    // Unmount so the repeat controller is disposed cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('MascotWidget reflects a saved profile (girl, dark tone)', (
    tester,
  ) async {
    final profile = DietProfile(
      weightKg: 58,
      heightCm: 162,
      age: 26,
      gender: Gender.female,
      goal: Goal.maintain,
      activity: ActivityLevel.moderate,
      skinTone: 'dark',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: MascotWidget(size: 100, profile: profile)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
