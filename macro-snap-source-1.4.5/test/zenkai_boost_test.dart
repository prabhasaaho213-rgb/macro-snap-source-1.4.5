import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/widgets/celebration.dart';
import 'package:macro_snap/widgets/mascot.dart';

/// Pins the Zenkai Boost overlay: it must show the recovery message with the
/// hero (power-up) mascot, play the transformation cleanly, and auto-dismiss.
/// Uses fixed pumps because the mascot's animations repeat forever.
void main() {
  testWidgets('zenkai boost shows hero mascot + message and auto-dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showZenkaiBoost(context, brokenStreak: 12),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump(); // start the route push
    await tester.pump(const Duration(milliseconds: 300)); // transition in

    expect(find.text('ZENKAI BOOST! 🔥'), findsOneWidget);
    expect(find.textContaining('12-day streak'), findsOneWidget);
    expect(find.byType(MascotWidget), findsOneWidget);

    // Let the mascot's power-up transformation (hair morph + flash) play.
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    // Let the auto-dismiss controller complete + the reverse transition.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('ZENKAI BOOST! 🔥'),
      findsNothing,
      reason: 'the overlay must dismiss itself',
    );
    expect(tester.takeException(), isNull);
  });
}
