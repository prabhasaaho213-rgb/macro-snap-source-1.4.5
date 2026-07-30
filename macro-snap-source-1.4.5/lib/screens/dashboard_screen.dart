import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../services/meal_store.dart';
import '../models/meal_record.dart';
import '../models/habit.dart';
import '../services/habit_store.dart';
import '../services/scan_gate.dart';
import '../services/meal_streak_service.dart';
import '../models/diet_profile.dart';
import '../services/share_service.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/animations.dart';
import '../widgets/consistency_map.dart';
import '../widgets/gradient_button.dart';
import 'diet_plan_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'recipe_list_screen.dart';
import 'barcode_scan_screen.dart';
import 'subscription_screen.dart';

/// Unified daily command center — merges habits, meals, water, scan trigger,
/// and progress stats into one scrollable dashboard.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _heroAnimController;
  late Animation<double> _heroFadeAnim;
  late Animation<Offset> _heroSlideAnim;

  HabitStore get habitStore => HabitStore.instance;

  String _name = '';
  bool _subscribed = false;
  int _streak = 0;
  int _bestStreak = 0;
  int _scansLeft = 3;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _heroAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroFadeAnim =
        CurvedAnimation(parent: _heroAnimController, curve: Curves.easeOut);
    _heroSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroAnimController,
      curve: Curves.easeOut,
    ));

    MealStore.instance.changeNotifier.addListener(_onDataChanged);
    habitStore.addListener(_onHabitChanged);
    _loadAll();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
    _loadScansOnly();
  }

  void _onHabitChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    await MealStore.instance.load();
    await habitStore.load();
    await DietPlanService.instance.load();
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? '';
    final subscribed = prefs.getBool('subscribed') ?? false;
    await MealStreakService.checkAndUpdate();
    final streak = await MealStreakService.getCurrent();
    final best = await MealStreakService.getBest();
    final scans = await ScanGate.getScansRemaining();

    final allHit = MealStreakService.checkAllTargetsHit();
    final alreadyPlayed =
        prefs.getBool('confetti_${DateTime.now().day}_${DateTime.now().month}') ?? false;

    if (mounted) {
      setState(() {
        _name = name;
        _subscribed = subscribed;
        _streak = streak;
        _bestStreak = best;
        _scansLeft = scans;
        if (allHit && !alreadyPlayed) {
          _showConfetti = true;
          prefs.setBool('confetti_${DateTime.now().day}_${DateTime.now().month}', true);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showConfetti = false);
          });
        }
      });
      _heroAnimController.forward();
    }
  }

  Future<void> _loadScansOnly() async {
    final scans = await ScanGate.getScansRemaining();
    if (mounted) setState(() => _scansLeft = scans);
  }

  @override
  void dispose() {
    MealStore.instance.changeNotifier.removeListener(_onDataChanged);
    habitStore.removeListener(_onHabitChanged);
    _heroAnimController.stop();
    _heroAnimController.dispose();
    super.dispose();
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meals = MealStore.instance.todayMeals;
    final todayCal = MealStore.instance.todayCalories;
    final todayP = MealStore.instance.todayProtein;
    final todayC = MealStore.instance.todayCarbs;
    final todayF = MealStore.instance.todayFats;
    final profile = DietPlanService.instance.profile;
    final targetCal = profile?.targetCalories ?? 2000;
    final targetP = profile?.targetProtein ?? 150;
    final targetC = profile?.targetCarbs ?? 300;
    final targetF = profile?.targetFats ?? 67;
    final calProgress = (todayCal / targetCal).clamp(0.0, 1.0);

    final activeHabits = habitStore.todayHabits;
    final completedHabits = habitStore.todayCompleted;
    final habitProgress =
        activeHabits.isEmpty ? 0.0 : completedHabits / activeHabits.length;
    final waterProgress = habitStore.waterGoal > 0
        ? (habitStore.waterToday / habitStore.waterGoal).clamp(0.0, 1.0)
        : 0.0;

    // Combined overall progress
    final overallProgress = (habitProgress + calProgress + waterProgress) / 3;

    return Scaffold(
      backgroundColor:
          isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surfaceLight,
      body: SafeArea(
        child: ConfettiOverlay(
          show: _showConfetti,
          child: SlideTransition(
            position: _heroSlideAnim,
            child: FadeTransition(
              opacity: _heroFadeAnim,
              child: RefreshIndicator(
                color: MacroSnapTheme.neonGreen,
                backgroundColor: isDark ? MacroSnapTheme.cardDark : Colors.white,
                onRefresh: () async {
                  await habitStore.load();
                  await MealStore.instance.load();
                  await _loadAll();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 14),
                    AnimatedEntrance(
                      delayMs: 30,
                      child: _buildHeroOverall(overallProgress, isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 60,
                      child: _buildScanButton(isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 90,
                      child: _buildMissionsSection(activeHabits, completedHabits, isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 120,
                      child: _buildCalorieRing(todayCal, targetCal, calProgress, isDark),
                    ),
                    const SizedBox(height: 14),
                    AnimatedEntrance(
                      delayMs: 140,
                      child: _buildMacroBars(todayP, targetP, todayC, targetC, todayF, targetF, isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 160,
                      child: _buildWaterCard(waterProgress, isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 180,
                      child: _buildStreakCard(isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 200,
                      child: _buildTodayMeals(meals, isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 220,
                      child: _buildQuickActions(isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 240,
                      child: _buildConsistencyMap(isDark),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delayMs: 260,
                      child: _buildWeekStrip(isDark),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 18
            ? 'Good Afternoon'
            : 'Good Evening';
    final today = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${weekdayLabel(today.weekday)}, ${months[today.month - 1]} ${today.day}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MacroSnapTheme.textSecondary(context))),
              const SizedBox(height: 2),
              Text(_name.isNotEmpty ? _name : 'MacroSnap',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
              const SizedBox(height: 2),
              Text(dateStr,
                  style: TextStyle(
                      fontSize: 13,
                      color: MacroSnapTheme.textTertiary(context))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: MacroSnapTheme.neonPill(
            _scansLeft > 0 ? MacroSnapTheme.neonGreen : MacroSnapTheme.neonPink,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded,
                  size: 14,
                  color: _scansLeft > 0
                      ? MacroSnapTheme.neonGreen
                      : MacroSnapTheme.neonPink),
              const SizedBox(width: 4),
              Text(_scansLeft >= 99 ? 'Unlimited' : '$_scansLeft',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _scansLeft > 0
                          ? MacroSnapTheme.neonGreen
                          : MacroSnapTheme.neonPink)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        ScaleOnPress(
          onTap: () =>
              Navigator.push(context, habitFlowRoute(const SettingsScreen())),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? MacroSnapTheme.cardDark : const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.settings_rounded,
                size: 20, color: MacroSnapTheme.textSecondary(context)),
          ),
        ),
      ],
    );
  }

  // ─── HERO OVERALL PROGRESS ─────────────────────────────
  Widget _buildHeroOverall(double progress, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: MacroSnapTheme.habitlyHeroCard(context),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  backgroundColor: Colors.white10,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(MacroSnapTheme.neonPink),
                ),
                Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TODAY'S PROGRESS",
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Keep the momentum going',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        MacroSnapTheme.neonGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SCAN TRIGGER ──────────────────────────────────────
  Widget _buildScanButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            habitFlowRoute(ScanScreen(
              key: ValueKey('scan_${DateTime.now().millisecondsSinceEpoch}'),
            )),
          );
        },
        icon: Icon(
            _scansLeft > 0 ? Icons.camera_alt_rounded : Icons.flash_on_rounded),
        label: Text(
          _scansLeft > 0
              ? 'SNAP A MEAL — $_scansLeft scan${_scansLeft == 1 ? '' : 's'} left'
              : 'SCANS USED UP — GO PRO',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              _scansLeft > 0 ? MacroSnapTheme.neonGreen : MacroSnapTheme.neonOrange,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  // ─── TODAY'S MISSIONS ─────────────────────────────────
  Widget _buildMissionsSection(List<Habit> active, int completed, bool isDark) {
    final hasHabits = habitStore.habits.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.checklist_rounded,
                      color: MacroSnapTheme.neonGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Text("Today's Missions",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
              ],
            ),
            Text(
              hasHabits ? '$completed/${active.length}' : '',
              style: const TextStyle(
                  color: MacroSnapTheme.neonGreen, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasHabits) ...[
          _buildCreateMissionButton(isDark),
          const SizedBox(height: 10),
        ],
        if (!hasHabits)
          _buildEmptyMissions(isDark)
        else if (active.isEmpty)
          _buildEmptyActive(isDark)
        else
          ...active.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMissionCard(h, isDark),
              )),
        if (!_subscribed && hasHabits) ...[
          const SizedBox(height: 4),
          _buildLimitIndicator(isDark),
        ],
        if (!hasHabits) ...[
          const SizedBox(height: 12),
          _buildCreateMissionButton(isDark),
        ],
      ],
    );
  }

  Widget _buildCreateMissionButton(bool isDark) {
    final limitReached = habitStore.habitLimitReached;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: () => _onCreateTap(context),
        icon: Icon(
            limitReached && !_subscribed ? Icons.lock_rounded : Icons.add_rounded),
        label: Text(
          limitReached && !_subscribed
              ? 'GO PRO FOR UNLIMITED'
              : 'CREATE HABIT',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: limitReached && !_subscribed
              ? MacroSnapTheme.neonPurple
              : MacroSnapTheme.neonGreen.withValues(alpha: 0.15),
          foregroundColor: limitReached && !_subscribed
              ? Colors.white
              : MacroSnapTheme.neonGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildMissionCard(Habit h, bool isDark) {
    final done = h.isCompleted(DateTime.now());
    return Dismissible(
      key: ValueKey('dash_dismiss_${h.id}'),
      direction: DismissDirection.horizontal,
      background: _swipeBg(right: true),
      secondaryBackground: _swipeBg(right: false),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        if (dir == DismissDirection.startToEnd) {
          h.toggle(DateTime.now());
          habitStore.update(h);
        } else {
          h.completedDates.clear();
          h.skippedDates.clear();
          habitStore.update(h);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${h.name} streak reset'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        return false;
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          h.toggle(DateTime.now());
          habitStore.update(h);
        },
        onLongPress: () => _showMissionActions(context, h, isDark),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: MacroSnapTheme.habitlyCard(context),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: MacroSnapTheme.emojiContainer(h.color),
                child: Center(
                    child: Text(h.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            color: done
                                ? MacroSnapTheme.textTertiary(context)
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A)))),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: MacroSnapTheme.neonPink, size: 14),
                        const SizedBox(width: 3),
                        Text('${h.currentStreak()}d · ${h.frequency}',
                            style: TextStyle(
                                fontSize: 11,
                                color: MacroSnapTheme.textSecondary(context),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: done
                      ? MacroSnapTheme.neonGreen
                      : MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.bolt_rounded,
                  color: done ? Colors.black : MacroSnapTheme.neonGreen,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swipeBg({required bool right}) {
    final color = right ? MacroSnapTheme.neonGreen : MacroSnapTheme.neonOrange;
    final icon = right ? Icons.check_circle_rounded : Icons.refresh_rounded;
    final label = right ? 'Complete' : 'Reset';
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!right) ...[
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
          ] else ...[
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 24),
          ],
        ],
      ),
    );
  }

  void _showMissionActions(BuildContext context, Habit h, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
        decoration: BoxDecoration(
          color: isDark ? MacroSnapTheme.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MacroSnapTheme.borderSubtle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: MacroSnapTheme.emojiContainer(h.color),
                  child: Center(
                      child: Text(h.emoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(h.name,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A))),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _actionRow(
              icon: Icons.refresh_rounded,
              iconColor: MacroSnapTheme.neonOrange,
              title: 'Reset Streak',
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                h.completedDates.clear();
                h.skippedDates.clear();
                habitStore.update(h);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${h.name} streak reset'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            _actionRow(
              icon: Icons.delete_rounded,
              iconColor: MacroSnapTheme.neonPink,
              title: 'Delete Habit',
              isDark: isDark,
              onTap: () async {
                Navigator.pop(ctx);
                await habitStore.remove(h);
              },
            ),

          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMissions(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFF8F6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF303045) : const Color(0xFFD4C9FF),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text('Start your rhythm',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          Text('Create habits to track daily missions',
              style: TextStyle(
                  fontSize: 13,
                  color: MacroSnapTheme.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildEmptyActive(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Center(
        child: Column(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text('All missions done for today!',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MacroSnapTheme.neonGreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitIndicator(bool isDark) {
    final used = habitStore.habits.length;
    final limit = HabitStore.freeHabitLimit;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? MacroSnapTheme.neonOrange.withValues(alpha: 0.08)
            : MacroSnapTheme.neonOrange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MacroSnapTheme.neonOrange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: used >= limit
                  ? MacroSnapTheme.neonOrange
                  : MacroSnapTheme.neonGreen,
              size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              used >= limit
                  ? 'Upgrade to Pro for unlimited habits'
                  : '${limit - used} free habit${limit - used == 1 ? '' : 's'} remaining',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MacroSnapTheme.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  void _onCreateTap(BuildContext context) {
    if (habitStore.habitLimitReached && !_subscribed) {
      _showProUpsell(context);
    } else {
      _showCreateHabitSheet(context);
    }
  }

  // ─── CALORIE RING ─────────────────────────────────────
  Widget _buildCalorieRing(int consumed, int target, double progress, bool isDark) {
    final remaining = max(target - consumed, 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MacroSnapTheme.neonOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: MacroSnapTheme.neonOrange, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Calories',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
              const Spacer(),
              Text('$consumed / $target',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: MacroSnapTheme.neonOrange)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  isDark ? const Color(0xFF303030) : const Color(0xFFE8DEFF),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MacroSnapTheme.neonOrange),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).round()}% of daily goal',
                  style: TextStyle(
                      fontSize: 12,
                      color: MacroSnapTheme.textSecondary(context))),
              if (remaining > 0)
                Text('$remaining kcal remaining',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MacroSnapTheme.neonGreen)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── MACRO BARS ───────────────────────────────────────
  Widget _buildMacroBars(
      double p, double tp, double c, double tc, double f, double tf, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macros',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          const SizedBox(height: 16),
          _macroLine('Protein', p, tp, MacroSnapTheme.neonPink, isDark),
          const SizedBox(height: 12),
          _macroLine('Carbs', c, tc, MacroSnapTheme.macroCarbs, isDark),
          const SizedBox(height: 12),
          _macroLine('Fats', f, tf, MacroSnapTheme.macroFats, isDark),
        ],
      ),
    );
  }

  Widget _macroLine(
      String label, double value, double target, Color color, bool isDark) {
    final pct = (value / max(target, 1)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MacroSnapTheme.textSecondary(context))),
              ],
            ),
            Text('${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}g',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MacroSnapTheme.textTertiary(context))),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedProgressBar(value: pct, color: color, height: 7),
      ],
    );
  }

  // ─── WATER INTAKE ────────────────────────────────────
  Widget _buildWaterCard(double progress, bool isDark) {
    final glasses = habitStore.waterToday;
    final goal = habitStore.waterGoal;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: MacroSnapTheme.neonCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.water_drop_rounded,
                        color: MacroSnapTheme.neonCyan, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Water',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A))),
                ],
              ),
              Text('$glasses / $goal glasses',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: MacroSnapTheme.neonCyan)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: List.generate(goal, (i) {
              final filled = i < glasses;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (filled) {
                    habitStore.removeWater();
                  } else {
                    habitStore.addWater();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: filled
                        ? MacroSnapTheme.neonCyan.withValues(alpha: 0.2)
                        : (isDark
                            ? const Color(0xFF303030)
                            : const Color(0xFFE8DEFF)),
                    borderRadius: BorderRadius.circular(9),
                    border: filled
                        ? Border.all(
                            color: MacroSnapTheme.neonCyan.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Icon(
                    filled
                        ? Icons.water_drop_rounded
                        : Icons.water_drop_outlined,
                    color: filled
                        ? MacroSnapTheme.neonCyan
                        : MacroSnapTheme.textQuaternary(context),
                    size: 16,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor:
                  isDark ? const Color(0xFF303030) : const Color(0xFFE8DEFF),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MacroSnapTheme.neonCyan),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STREAK CARD ──────────────────────────────────────
  Widget _buildStreakCard(bool isDark) {
    final isBest = MealStreakService.isLongestStreak(_streak, _bestStreak);
    final habitStreak = habitStore.habits.isEmpty
        ? 0
        : habitStore.habits.map((h) => h.currentStreak()).reduce(max);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: MacroSnapTheme.emojiContainer(MacroSnapTheme.neonPink),
            child: const Icon(Icons.local_fire_department_rounded,
                color: MacroSnapTheme.neonPink, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Streaks',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MacroSnapTheme.textTertiary(context),
                        letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('$_streak',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A))),
                    const SizedBox(width: 3),
                    Text('meal · ',
                        style: TextStyle(
                            fontSize: 13,
                            color: MacroSnapTheme.textSecondary(context))),
                    Text('$habitStreak',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A))),
                    const SizedBox(width: 3),
                    Text('habit',
                        style: TextStyle(
                            fontSize: 13,
                            color: MacroSnapTheme.textSecondary(context))),
                  ],
                ),
                Text(
                  isBest ? 'Personal best! 🔥' : 'Best: $_bestStreak days',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isBest
                          ? MacroSnapTheme.neonGreen
                          : MacroSnapTheme.textTertiary(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: MacroSnapTheme.neonPill(MacroSnapTheme.neonGreen),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded,
                    size: 14, color: MacroSnapTheme.neonGreen),
                const SizedBox(width: 3),
                Text('+$_streak',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MacroSnapTheme.neonGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TODAY'S MEALS ────────────────────────────────────
  Widget _buildTodayMeals(List<MealRecord> meals, bool isDark) {
    if (meals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.neonOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded,
                      color: MacroSnapTheme.neonOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Text("Today's Meals",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1A1A))),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: MacroSnapTheme.neonPill(MacroSnapTheme.neonGreen),
              child: Text('${meals.fold(0, (s, m) => s + m.calories)} kcal',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: MacroSnapTheme.neonGreen)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...meals.take(5).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildMealCard(m, isDark),
            )),
      ],
    );
  }

  Widget _buildMealCard(MealRecord m, bool isDark) {
    final color = _mealColor(m);
    final icon = _mealIcon(m);
    return GestureDetector(
      onLongPress: () => _showDeleteMealDialog(m, isDark),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: MacroSnapTheme.habitlyCard(context),
        child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: MacroSnapTheme.emojiContainer(color),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1A1A))),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: MacroSnapTheme.neonPink, size: 14),
                    const SizedBox(width: 3),
                    Text('${m.calories} kcal',
                        style: TextStyle(
                            fontSize: 12,
                            color: MacroSnapTheme.textSecondary(context),
                            fontWeight: FontWeight.w600)),
                    if (m.serving.isNotEmpty)
                      Text(' · ${m.serving}',
                          style: TextStyle(
                              fontSize: 11,
                              color: MacroSnapTheme.textTertiary(context))),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.protein > 0)
                _macroDot(MacroSnapTheme.neonPink, m.protein.toStringAsFixed(0)),
              if (m.carbs > 0)
                _macroDot(MacroSnapTheme.macroCarbs, m.carbs.toStringAsFixed(0)),
              if (m.fats > 0)
                _macroDot(MacroSnapTheme.macroFats, m.fats.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    ),
  );
  }

  void _showDeleteMealDialog(MealRecord m, bool isDark) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? MacroSnapTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Delete Meal',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove "${m.name}" from your log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: MacroSnapTheme.neonPink,
              foregroundColor: Colors.black,
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        MealStore.instance.remove(m.id);
        if (mounted) setState(() {});
      }
    });
  }

  Widget _macroDot(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Color _mealColor(MealRecord m) {
    final h = m.date.hour;
    if (h >= 5 && h < 11) return MacroSnapTheme.macroCalories;
    if (h >= 11 && h < 15) return MacroSnapTheme.neonGreen;
    if (h >= 17 && h < 22) return MacroSnapTheme.macroFats;
    return MacroSnapTheme.macroProtein;
  }

  IconData _mealIcon(MealRecord m) {
    final h = m.date.hour;
    if (h >= 5 && h < 11) return Icons.wb_sunny_rounded;
    if (h >= 11 && h < 15) return Icons.restaurant_rounded;
    if (h >= 17 && h < 22) return Icons.nights_stay_rounded;
    return Icons.cookie_rounded;
  }

  // ─── QUICK ACTIONS ───────────────────────────────────
  Widget _buildQuickActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _actionChip(Icons.qr_code_scanner_rounded, 'Barcode',
                  MacroSnapTheme.neonCyan, () {
                Navigator.push(
                    context, habitFlowRoute(const BarcodeScanScreen()));
              }),
              _actionChip(Icons.auto_awesome_rounded, 'Diet Plan',
                  MacroSnapTheme.neonPurple, () async {
                await DietPlanService.instance.load();
                if (context.mounted) {
                  Navigator.push(
                      context, habitFlowRoute(const DietPlanScreen()));
                }
              }),
              _actionChip(Icons.menu_book_rounded, 'Recipes',
                  MacroSnapTheme.neonPink, () {
                Navigator.push(
                    context, habitFlowRoute(const RecipeListScreen()));
              }),
              _actionChip(Icons.share_rounded, 'Share',
                  MacroSnapTheme.neonGreen, () async {
                final shared = await ShareService.shareWeekSummary();
                if (!shared && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('No meals logged this week yet.'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ScaleOnPress(
      onTap: onTap,
      scaleAmount: 0.93,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(minWidth: 64),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MacroSnapTheme.textPrimaryMuted(context))),
          ],
        ),
      ),
    );
  }

  // ─── CONSISTENCY MAP ─────────────────────────────────
  Widget _buildConsistencyMap(bool isDark) {
    final active = habitStore.habits.where((h) => !h.paused).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        color: MacroSnapTheme.neonGreen, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Consistency',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A))),
                ],
              ),
              Text('${active.length} habits',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MacroSnapTheme.textTertiary(context))),
            ],
          ),
          const SizedBox(height: 14),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Create habits to see consistency',
                    style: TextStyle(
                        fontSize: 13,
                        color: MacroSnapTheme.textTertiary(context))),
              ),
            )
          else
            ConsistencyMap(
              habits: active,
              onCellTap: (date, count, names) =>
                  _showDayDetail(date, count, names),
            ),
        ],
      ),
    );
  }

  void _showDayDetail(DateTime date, int count, List<String> habitNames) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dayDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(now.year, now.month, now.day);

    String title;
    if (dayDate == todayDate) {
      title = 'Today';
    } else if (dayDate == todayDate.subtract(const Duration(days: 1))) {
      title = 'Yesterday';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      title = '${months[date.month - 1]} ${date.day}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 36),
        decoration: BoxDecoration(
          color: isDark ? MacroSnapTheme.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MacroSnapTheme.borderSubtle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: MacroSnapTheme.neonGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A))),
                    Text('$count/${habitNames.length} habits completed',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MacroSnapTheme.textTertiary(context))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (habitNames.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      const Text('😴', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 6),
                      Text('Nothing logged this day',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: MacroSnapTheme.textTertiary(context))),
                    ],
                  ),
                ),
              )
            else
              ...habitNames.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: MacroSnapTheme.neonGreen, size: 14),
                        ),
                        const SizedBox(width: 10),
                        Text(name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A))),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // ─── WEEK STRIP ──────────────────────────────────────
  Widget _buildWeekStrip(bool isDark) {
    final meals = MealStore.instance.allMeals;
    final now = DateTime.now();
    final dayMeals = <String, List<MealRecord>>{};
    for (final m in meals) {
      final key = '${m.date.year}-${m.date.month}-${m.date.day}';
      dayMeals.putIfAbsent(key, () => []).add(m);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MacroSnapTheme.habitlyCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Week',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color:
                          isDark ? Colors.white : const Color(0xFF1A1A1A))),
              ScaleOnPress(
                onTap: () async {
                  final shared = await ShareService.shareWeekSummary();
                  if (!shared && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            const Text('No meals logged this week yet.'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share_rounded,
                      size: 16, color: MacroSnapTheme.neonGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final d = DateTime(now.year, now.month, now.day - (6 - i));
              final key = '${d.year}-${d.month}-${d.day}';
              final dayList = dayMeals[key] ?? [];
              final logged = dayList.isNotEmpty;
              final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final isToday = d.day == now.day &&
                  d.month == now.month &&
                  d.year == now.year;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(days[d.weekday - 1],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isToday
                              ? MacroSnapTheme.neonGreen
                              : MacroSnapTheme.textTertiary(context))),
                  const SizedBox(height: 6),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: logged
                          ? MacroSnapTheme.neonGreen.withValues(alpha: 0.2)
                          : (isDark
                              ? const Color(0xFF303030)
                              : const Color(0xFFE8DEFF)),
                      border: isToday
                          ? Border.all(
                              color: MacroSnapTheme.neonGreen, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: logged
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: MacroSnapTheme.neonGreen)
                          : Text('${d.day}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: MacroSnapTheme
                                      .textQuaternary(context))),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (dayList.isNotEmpty)
                    Text('${dayList.fold(0, (s, m) => s + m.calories)}',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: MacroSnapTheme.neonGreen
                                .withValues(alpha: 0.7))),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── CREATE HABIT SHEET ──────────────────────────────
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: MacroSnapTheme.neonGreen, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Habit limit reached',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Text(
                'Free users get ${HabitStore.freeHabitLimit} habits.\nGo Pro for unlimited habits, AI scans & more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: MacroSnapTheme.textSecondary(context),
                    height: 1.4)),
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
                  style: TextStyle(
                      fontSize: 14,
                      color: MacroSnapTheme.textTertiary(context))),
            ),
          ]),
        ),
      ),
    );
  }

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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
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
                    fillColor:
                        Theme.of(ctx).colorScheme.surfaceContainerHighest,
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
                  children: [
                    '✨', '💧', '📚', '🏃', '🧘', '🎸', '🍎', '💻', '🎯', '😴', '🧠', '☕'
                  ]
                      .map((e) => ChoiceChip(
                            label:
                                Text(e, style: const TextStyle(fontSize: 20)),
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
                            onSelected: (_) =>
                                setModalState(() => frequency = e),
                          ))
                      .toList(),
                ),
                if (frequency == 'Weekly') ...[
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
                ],
                const SizedBox(height: 18),
                const Text('Color',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    0xFF00FF66,
                    0xFFFF007F,
                    0xFF6C3BFF,
                    0xFFFF9500,
                    0xFF34C759,
                    0xFF00B8D4,
                  ].map((value) => GestureDetector(
                        onTap: () => setModalState(() => color = value),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == value
                                  ? Theme.of(ctx).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      )).toList(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
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
                      await habitStore.add(habit);
                      if (ctx.mounted) Navigator.pop(ctx);
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
