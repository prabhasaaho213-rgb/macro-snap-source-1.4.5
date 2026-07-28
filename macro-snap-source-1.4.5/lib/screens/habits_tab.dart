import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../models/habit.dart';
import '../services/habit_store.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';
import 'subscription_screen.dart';

class HabitsTab extends StatefulWidget {
  const HabitsTab({super.key});

  @override
  State<HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<HabitsTab> {
  HabitStore get store => HabitStore.instance;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_onChanged);
    _checkSub();
  }

  Future<void> _checkSub() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _subscribed = p.getBool('subscribed') ?? false);
  }

  @override
  void dispose() {
    store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      _checkSub();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final active = store.todayHabits;
    final completed = store.todayCompleted;
    final progress = active.isEmpty ? 0.0 : completed / active.length;
    final waterProgress = store.waterGoal > 0
        ? (store.waterToday / store.waterGoal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
          children: [
            // Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Habits',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    _coinPill(isDark),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${weekdayLabel(DateTime.now().weekday)}, ${_monthDay(today)}',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),

            // ─── Hero Card ──────────────────────────────────
            AnimatedEntrance(
              delayMs: 0,
              child: _heroCard(progress, completed, active.length, isDark),
            ),
            const SizedBox(height: 18),

            // ─── Water Tracker ───────────────────────────────
            AnimatedEntrance(
              delayMs: 50,
              child: _waterCard(waterProgress, isDark),
            ),
            const SizedBox(height: 24),

            // ─── Today's Missions ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Missions",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text(
                  '$completed/${active.length}',
                  style: const TextStyle(
                    color: MacroSnapTheme.neonGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (active.isEmpty)
              _emptyState(isDark)
            else
              ...active.map((h) => AnimatedEntrance(
                delayMs: 50 + active.indexOf(h) * 30,
                child: _missionCard(h, isDark),
              )),

            // ─── Habit Limit Indicator ───────────────────────
            if (!_subscribed && store.habits.isNotEmpty) ...[
              AnimatedEntrance(
                delayMs: 50 + store.habits.length * 30,
                child: _habitLimitCard(isDark),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),

            // ─── Create Habit Button ─────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => _onCreateTap(context),
                icon: Icon(store.habitLimitReached && !_subscribed
                    ? Icons.lock_rounded
                    : Icons.add_rounded),
                label: Text(
                  store.habitLimitReached && !_subscribed
                      ? 'GO PRO FOR UNLIMITED'
                      : 'CREATE HABIT',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
                style: FilledButton.styleFrom(
                  backgroundColor: store.habitLimitReached && !_subscribed
                      ? MacroSnapTheme.neonPurple
                      : MacroSnapTheme.neonGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthDay(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  // ─── COIN PILL ─────────────────────────────────────────────
  Widget _coinPill(bool isDark) {
    final coins = store.totalStreakPower;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? MacroSnapTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF303030) : const Color(0xFFE8DEFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: MacroSnapTheme.neonGreen, size: 18),
          const SizedBox(width: 4),
          Text('$coins HC',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ─── HERO CARD ─────────────────────────────────────────────
  Widget _heroCard(double progress, int completed, int total, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: MacroSnapTheme.habitlyHeroCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TODAY',
                      style: TextStyle(
                        color: Colors.white54, fontSize: 12,
                        letterSpacing: 1.4, fontWeight: FontWeight.w800,
                      )),
                  SizedBox(height: 5),
                  Text('Make it count.',
                      style: TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white,
                      )),
                ],
              ),
              _progressRing(progress),
            ],
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(MacroSnapTheme.neonGreen),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                total == 0
                    ? 'Create your first habit'
                    : '$completed of $total missions complete',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: MacroSnapTheme.neonPink, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${store.totalStreakPower} streak power',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressRing(double progress) {
    return SizedBox(
      width: 72, height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 7,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(MacroSnapTheme.neonPink),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ─── WATER TRACKER ─────────────────────────────────────────
  Widget _waterCard(double progress, bool isDark) {
    final glasses = store.waterToday;
    final goal = store.waterGoal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('💧', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Text('Water Intake',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
              Text('$glasses / $goal',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: MacroSnapTheme.neonCyan,
                  )),
            ],
          ),
          const SizedBox(height: 14),

          // Water glass icons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(goal, (i) {
              final filled = i < glasses;
              return GestureDetector(
                onTap: filled ? store.removeWater : store.addWater,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: filled
                        ? MacroSnapTheme.neonCyan.withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF303030) : const Color(0xFFE8DEFF)),
                    borderRadius: BorderRadius.circular(10),
                    border: filled
                        ? Border.all(color: MacroSnapTheme.neonCyan.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Icon(
                    filled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                    color: filled ? MacroSnapTheme.neonCyan : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                    size: 18,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF303030) : const Color(0xFFE8DEFF),
              valueColor: const AlwaysStoppedAnimation<Color>(MacroSnapTheme.neonCyan),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MISSION CARD ──────────────────────────────────────────
  Widget _missionCard(Habit h, bool isDark) {
    final done = h.isCompleted(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          h.toggle(DateTime.now());
          store.update(h);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: MacroSnapTheme.habitlyCard(context),
          child: Row(
            children: [
              // Emoji container
              Container(
                width: 52, height: 52,
                decoration: MacroSnapTheme.emojiContainer(h.color),
                child: Center(
                  child: Text(h.emoji, style: const TextStyle(fontSize: 25)),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.name,
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done
                            ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                            : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: MacroSnapTheme.neonPink, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${h.currentStreak()} day streak · ${h.frequency}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 12, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Check/Bolt button
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: done
                      ? MacroSnapTheme.neonGreen
                      : MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.bolt_rounded,
                  color: done ? Colors.black : MacroSnapTheme.neonGreen,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HABIT LIMIT CARD ─────────────────────────────────────
  Widget _habitLimitCard(bool isDark) {
    final used = store.habits.length;
    final limit = HabitStore.freeHabitLimit;
    final pct = (used / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: used >= limit ? MacroSnapTheme.neonOrange : MacroSnapTheme.neonGreen,
                  size: 18),
              const SizedBox(width: 8),
              Text('Habit Limit',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  )),
              const Spacer(),
              Text('$used / $limit',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: used >= limit ? MacroSnapTheme.neonOrange : MacroSnapTheme.neonGreen,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF303030) : const Color(0xFFE8DEFF),
              valueColor: AlwaysStoppedAnimation<Color>(
                used >= limit ? MacroSnapTheme.neonOrange : MacroSnapTheme.neonGreen,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            used >= limit
                ? 'Upgrade to Pro for unlimited habits'
                : '${limit - used} habit${limit - used == 1 ? '' : 's'} remaining on Free',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CREATE TAP HANDLER ────────────────────────────────────
  void _onCreateTap(BuildContext context) {
    if (store.habitLimitReached && !_subscribed) {
      _showProUpsell(context);
    } else {
      _showCreateHabitSheet(context);
    }
  }

  // ─── PRO UPSELL ────────────────────────────────────────────
  void _showProUpsell(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? MacroSnapTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: MacroSnapTheme.neonGreen, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Habit limit reached',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Text('Free users get ${HabitStore.freeHabitLimit} habits.\nGo Pro for unlimited habits, AI scans & more.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B), height: 1.4)),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Go Pro - ₹29/mo',
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },
              height: 48,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Maybe later',
                  style: TextStyle(fontSize: 14,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────
  Widget _emptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? MacroSnapTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Text('✨', style: TextStyle(fontSize: 42)),
          SizedBox(height: 10),
          Text('Start your rhythm',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text(
            'Add a habit and turn small wins into momentum.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ─── CREATE HABIT SHEET ────────────────────────────────────
  Future<void> _showCreateHabitSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    var emoji = '✨';
    var frequency = 'Daily';
    var color = 0xFF00FF66;
    var weeklyDay = DateTime.now().weekday;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 22, right: 22, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create a mission',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'What do you want to build?',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Choose an icon',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['✨', '💧', '📚', '🏃', '🧘', '🎸', '🍎', '💻', '🎯', '😴', '🧠', '☕']
                      .map((e) => ChoiceChip(
                            label: Text(e, style: const TextStyle(fontSize: 20)),
                            selected: emoji == e,
                            onSelected: (_) => setModalState(() => emoji = e),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                const Text('Frequency',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['Daily', 'Weekdays', 'Weekly']
                      .map((e) => ChoiceChip(
                            label: Text(e),
                            selected: frequency == e,
                            onSelected: (_) => setModalState(() => frequency = e),
                          ))
                      .toList(),
                ),
                if (frequency == 'Weekly') ...{
                  const SizedBox(height: 14),
                  const Text('Weekly day',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (index) {
                      final wd = index + 1;
                      return ChoiceChip(
                        label: Text(weekdayLabel(wd)),
                        selected: weeklyDay == wd,
                        onSelected: (_) => setModalState(() => weeklyDay = wd),
                      );
                    }),
                  ),
                },
                const SizedBox(height: 18),
                const Text('Color',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    0xFF00FF66, 0xFFFF007F, 0xFF6C3BFF,
                    0xFFFF9500, 0xFF34C759, 0xFF00B8D4,
                  ].map((value) => GestureDetector(
                        onTap: () => setModalState(() => color = value),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == value
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      )).toList(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MacroSnapTheme.neonGreen,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final habit = Habit(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        emoji: emoji,
                        colorValue: color,
                        frequency: frequency,
                        weeklyDay: weeklyDay,
                      );
                      await store.add(habit);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('CREATE MISSION',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
  }
}
