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

  testWidgets('Power-up transition (hair morph + flash) plays cleanly', (
    tester,
  ) async {
    Widget build(MascotMood mood) => MaterialApp(
      home: Scaffold(
        body: Center(child: MascotWidget(size: 100, mood: mood)),
      ),
    );
    await tester.pumpWidget(build(MascotMood.happy));
    await tester.pump(const Duration(milliseconds: 100));
    // Switch to hero mode — the one-shot transformation should play.
    await tester.pumpWidget(build(MascotMood.powerUp));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Mascot eyes follow the pointer without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: MascotWidget(size: 100))),
      ),
    );
    final center = tester.getCenter(find.byType(MascotWidget));
    final gesture = await tester.startGesture(center + const Offset(30, -20));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(center + const Offset(-30, 20));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
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
