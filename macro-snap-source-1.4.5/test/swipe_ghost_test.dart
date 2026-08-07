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

    // Ghost-fix structure: the emoji tile's glow/blur shadow is the only
    // thing that smears during a swipe, so it must be isolated in its own
    // RepaintBoundary. The boundary must NOT wrap the whole card — a whole-
    // card raster layer renders a black rectangle that slides with the card
    // on some GPUs (the black-box glitch).
    final dismissible = find.byType(Dismissible).first;
    expect(dismissible, findsWidgets,
        reason: 'mission card must be a Dismissible');
    final dismissibleWidget = tester.widget<Dismissible>(dismissible);
    expect(dismissibleWidget.child, isNot(isA<RepaintBoundary>()),
        reason:
            'the whole card must NOT be wrapped in a RepaintBoundary — that '
            'renders a black rectangle sliding with the card on swipe '
            '(black-box fix)');

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

  test('emojiStyle is flat — no ghost shadows on the glyph', () {
    final style = MacroSnapTheme.emojiStyle();
    // Ghost-shadow fix: glyphs must render flat (no drop shadow / halo),
    // otherwise a dark shadow shows through as a ghost reflection on
    // emoji surfaces (picker chips, mission cards, actions sheet).
    expect(style.shadows, isNull);
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
    //
    // Persistence is now DEFERRED until after the snap-back (see
    // _missionCard): the Dismissible must finish moving to the dismissed
    // position first, then confirmDismiss runs and starts a 350ms deferred
    // persist timer, which needs one more pump to flush.
    await tester.drag(find.text('Morning Run'), const Offset(500, 0));
    await tester.pump(); // gesture ends → move-to-dismissed starts
    await tester.pump(const Duration(milliseconds: 400)); // move completes → confirmDismiss → 350ms persist timer starts
    await tester.pump(const Duration(milliseconds: 500)); // deferred persist (350ms) fires with margin → store.update + notify
    await tester.pump(const Duration(milliseconds: 300)); // snap-back reverse animation

    expect(h.isCompleted(now), isTrue,
        reason: 'swipe right = complete the habit');
    expect(find.text('Morning Run'), findsOneWidget,
        reason: 'confirmDismiss returns false → card snaps back, not removed');
  });

  testWidgets('swipe left un-completes today (does NOT reset the streak)',
      (tester) async {
    final store = HabitStore.instance;
    final h = Habit(
        id: 'v1',
        name: 'Morning Run',
        emoji: '🏃',
        colorValue: 0xFFFF007F,
        frequency: 'Daily');
    // Pre-complete today + yesterday so there is a streak that must survive.
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    h.completedDates.addAll([dateKey(now), dateKey(yesterday)]);
    store.habits.add(h);
    await pumpHabitsTab(tester);

    expect(h.currentStreak(), greaterThan(0));

    // Fixed pumps — StreakFlame's flicker repeats forever so pumpAndSettle
    // would time out. Same deferred-persist timing as the swipe-right test:
    // move completes → confirmDismiss → 350ms persist timer → flush it.
    await tester.drag(find.text('Morning Run'), const Offset(-500, 0));
    await tester.pump(); // gesture ends → move-to-dismissed starts
    await tester.pump(const Duration(milliseconds: 400)); // move completes → confirmDismiss → 350ms persist timer starts
    await tester.pump(const Duration(milliseconds: 500)); // deferred persist (350ms) fires with margin → store.update + notify + SnackBar
    await tester.pump(const Duration(milliseconds: 300)); // snap-back reverse animation

    expect(h.isCompleted(now), isFalse,
        reason: 'swipe left = un-complete today\'s task');
    expect(h.isCompleted(yesterday), isTrue,
        reason: 'swipe left must NOT reset the streak — past days stay intact');
    expect(find.text('Morning Run'), findsOneWidget,
        reason: 'confirmDismiss returns false → card snaps back, not removed');
  });

  testWidgets('swipe right on an already-completed habit keeps it completed',
      (tester) async {
    final store = HabitStore.instance;
    final h = Habit(
        id: 'v1',
        name: 'Morning Run',
        emoji: '🏃',
        colorValue: 0xFFFF007F,
        frequency: 'Daily');
    final now = DateTime.now();
    h.completedDates.add(dateKey(now)); // already completed
    store.habits.add(h);
    await pumpHabitsTab(tester);

    await tester.drag(find.text('Morning Run'), const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(h.isCompleted(now), isTrue,
        reason: 'swipe right = complete, never un-complete');
    expect(find.text('Morning Run'), findsOneWidget);
  });
}
