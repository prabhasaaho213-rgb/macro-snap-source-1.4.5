import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/widgets/celebration.dart';
import 'package:macro_snap/widgets/mascot.dart';

/// Pins the celebration overlay: it must show the message + celebrating
/// mascot and auto-dismiss itself (~1.9s) without leaking timers. Uses fixed
/// pumps because the mascot's idle animation repeats forever.
void main() {
  testWidgets('celebration shows mascot + message and auto-dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showCelebration(context, message: 'Meal logged!'),
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

    expect(find.text('Meal logged!'), findsOneWidget);
    expect(find.byType(MascotWidget), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the auto-dismiss controller complete + the reverse transition.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Meal logged!'),
      findsNothing,
      reason: 'the overlay must dismiss itself',
    );
    expect(tester.takeException(), isNull);
  });
}
