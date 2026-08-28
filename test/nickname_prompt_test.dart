import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/widgets/nickname_prompt.dart';

/// Pins the first-login nickname prompt: a 15-character limit so a nickname
/// can never overflow UI that shows it, Save returns the trimmed nickname,
/// and Skip dismisses without a value (so the user can enter the app).
void main() {
  String? result;

  Future<void> openPrompt(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showNicknamePrompt(context);
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('dialog enforces the 15-character limit', (tester) async {
    await openPrompt(tester);

    expect(find.text('Pick a nickname'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, kNicknameMaxLength);
    expect(kNicknameMaxLength, 15);

    // 25 characters typed → only 15 are kept.
    await tester.enterText(find.byType(TextField), 'X' * 25);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      kNicknameMaxLength,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'X' * 15);
  });

  testWidgets('Save returns the trimmed nickname', (tester) async {
    await openPrompt(tester);

    await tester.enterText(find.byType(TextField), '  MacroChamp  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'MacroChamp');
  });

  testWidgets('Skip dismisses with no nickname', (tester) async {
    await openPrompt(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Pick a nickname'), findsNothing);
  });
}
