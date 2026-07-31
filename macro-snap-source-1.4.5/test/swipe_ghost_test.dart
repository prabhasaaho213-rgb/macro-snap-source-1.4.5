import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macro_snap/core/theme.dart';
import 'package:macro_snap/screens/habits_tab.dart';
import 'package:macro_snap/models/habit.dart';
import 'package:macro_snap/services/habit_store.dart';

/// Pumps HabitsTab and waits for AnimatedEntrance+_checkSub to settle.
Future<void> pumpHabitsTab(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: HabitsTab()));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = HabitStore.instance;
    store.habits.clear();
  });

  // ─── GHOST FIX STRUCTURE ───────────────────────────────────
  // GPU smear during the swipe is a rasterization artifact, but it can only
  // happen if the emoji tile's blur shadows re-rasterize against the moving
  // Dismissible background each frame. The fix wraps the whole card in a
  // RepaintBoundary so it composites as ONE cached layer. These tests pin
  // that structure so a future refactor can't silently drop it.

  testWidgets('emoji tile lives inside a RepaintBoundary inside the Dismissible',
      (tester) async {
    final store = HabitStore.instance;
    store.habits.addAll([
      Habit(
          id: 'v1',
          name: 'Morning Run',
          emoji: '🏃',
          colorValue: 0xFFFF007F,
          frequency: 'Daily'),
    ]);
    await pumpHabitsTab(tester);

    final emoji = find.text('🏃');
    expect(emoji, findsOneWidget);

    // The RepaintBoundary (ghost fix) must be the DIRECT child of the
    // Dismissible, wrapping the card — if it's missing or moved outside, the
    // glow shadows are repainted raw against the swipe background.
    final dismissible = find.byType(Dismissible).first;
    expect(dismissible, findsWidgets,
        reason: 'mission card must be a Dismissible');
    final dismissibleWidget = tester.widget<Dismissible>(dismissible);
    expect(dismissibleWidget.child, isA<RepaintBoundary>(),
        reason:
            'RepaintBoundary must be the direct child of the Dismissible '
            '(swipe-ghost fix)');

    final boundary = find.ancestor(
      of: emoji,
      matching: find.byType(RepaintBoundary),
    );
    expect(boundary, findsWidgets,
        reason: 'RepaintBoundary must wrap the emoji tile (swipe-ghost fix)');
  });

  // ─── VIBRANCY FIX VALUES ───────────────────────────────────
  test('emojiContainer tile is vividly tinted (vibrancy change)', () {
    const c = Color(0xFF00FF66);
    final deco = MacroSnapTheme.emojiContainer(c);
    final gradient = deco.gradient! as LinearGradient;

    // Brighter background tint: 0.55 → 0.26 alpha (was 0.32 → 0.14).
    expect(gradient.colors.first.a, closeTo(0.55, 0.001));
    expect(gradient.colors.last.a, closeTo(0.26, 0.001));

    // Stronger colored border: 0.65 alpha (was 0.4).
    final border = deco.border! as Border;
    expect(border.top.color.a, closeTo(0.65, 0.001));

    // Stronger glow shadow: 0.35 alpha, blur 12 (was 0.18 / blur 8).
    final shadow = deco.boxShadow!.first;
    expect(shadow.color.a, closeTo(0.35, 0.001));
    expect(shadow.blurRadius, 12);
  });

  test('emojiStyle keeps the bright halo + drop shadow', () {
    final style = MacroSnapTheme.emojiStyle();
    expect(style.shadows, isNotNull);
    expect(style.shadows!.length, 2);
  });

  // ─── SWIPE BEHAVIOR (still works with the stronger glow) ───
  testWidgets('swipe right completes the habit and the card snaps back',
      (tester) async {
    final store = HabitStore.instance;
    final h = Habit(
        id: 'v1',
        name: 'Morning Run',
        emoji: '🏃',
        colorValue: 0xFFFF007F,
        frequency: 'Daily');
    store.habits.add(h);
    await pumpHabitsTab(tester);

    final now = DateTime.now();
    expect(h.isCompleted(now), isFalse);

    // >0.4 of the ~764px-wide card (Dismissible's default dismissThresholds)
    // so confirmDismiss actually fires. Fixed pumps (never pumpAndSettle):
    // StreakFlame's flicker controller repeats forever, so pumpAndSettle
    // would time out.
    await tester.drag(find.text('Morning Run'), const Offset(500, 0));
    await tester.pump(); // gesture ends → confirmDismiss starts
    await tester.pump(const Duration(milliseconds: 400)); // resolve confirmDismiss + async store.update
    await tester.pump(const Duration(milliseconds: 300)); // snap-back reverse animation

    expect(h.isCompleted(now), isTrue,
        reason: 'swipe right = complete the habit');
    expect(find.text('Morning Run'), findsOneWidget,
        reason: 'confirmDismiss returns false → card snaps back, not removed');
  });

  testWidgets('swipe left resets the streak and the card snaps back',
      (tester) async {
    final store = HabitStore.instance;
    final h = Habit(
        id: 'v1',
        name: 'Morning Run',
        emoji: '🏃',
        colorValue: 0xFFFF007F,
        frequency: 'Daily');
    // Pre-complete today + yesterday so there is a streak to reset.
    final now = DateTime.now();
    h.completedDates.addAll([
      dateKey(now),
      dateKey(now.subtract(const Duration(days: 1))),
    ]);
    store.habits.add(h);
    await pumpHabitsTab(tester);

    expect(h.currentStreak(), greaterThan(0));

    // Fixed pumps — StreakFlame's flicker repeats forever so pumpAndSettle
    // would time out.
    await tester.drag(find.text('Morning Run'), const Offset(-500, 0));
    await tester.pump(); // gesture ends → confirmDismiss starts
    await tester.pump(const Duration(milliseconds: 400)); // resolve confirmDismiss + async store.update + SnackBar
    await tester.pump(const Duration(milliseconds: 300)); // snap-back reverse animation

    expect(h.completedDates, isEmpty,
        reason: 'swipe left = reset the streak');
    expect(find.text('Morning Run'), findsOneWidget,
        reason: 'confirmDismiss returns false → card snaps back, not removed');
  });
}
