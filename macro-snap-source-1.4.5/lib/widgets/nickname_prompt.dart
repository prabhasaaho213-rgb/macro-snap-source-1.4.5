import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// Maximum nickname length (limited characters).
const int kNicknameMaxLength = 15;

/// Shows the first-login nickname picker. Returns the chosen nickname
/// (trimmed), or null when the user taps Skip.
///
/// Enforced [kNicknameMaxLength]-character limit so a nickname can never
/// overflow the home greeting or other UI that displays it.
Future<String?> showNicknamePrompt(BuildContext context) async {
  // The controller lives for the life of the one-shot modal — it must not be
  // disposed when `showDialog` resolves, because the dialog's exit animation
  // still rebuilds the TextField and would touch a disposed controller.
  final controller = TextEditingController();
  final chosen = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).brightness == Brightness.dark
          ? MacroSnapTheme.cardDark
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: const Text('Pick a nickname'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: kNicknameMaxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. MacroChamp 💪',
          counterText: '',
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: MacroSnapTheme.neonGreen,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return chosen?.trim().isEmpty ?? true ? null : chosen!.trim();
}
