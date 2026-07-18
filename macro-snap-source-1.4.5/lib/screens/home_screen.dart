import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../services/meal_store.dart';
import '../models/meal_record.dart';
import '../services/scan_gate.dart';
import '../services/streak_service.dart';
import '../models/diet_profile.dart';
import '../services/share_service.dart';

import '../widgets/confetti_overlay.dart';
import '../widgets/animations.dart';
import 'diet_plan_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'recipe_list_screen.dart';
import 'barcode_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  String _name = '';
  int _streak = 0;
  int _bestStreak = 0;
  int _scansLeft = 3;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _loadAll();
  }

  Future<void> _loadAll() async {
    await MealStore.instance.load();
    await DietPlanService.instance.load();
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? '';
    await StreakService.checkAndUpdate();
    final streak = await StreakService.getCurrent();
    final best = await StreakService.getBest();
    final scans = await ScanGate.getScansRemaining();

    // Check if all targets are hit for confetti
    final profile = DietPlanService.instance.profile;
    final p = MealStore.instance.todayProtein;
    final c = MealStore.instance.todayCarbs;
    final f = MealStore.instance.todayFats;
    final targetP = profile?.targetProtein ?? 150;
    final targetC = profile?.targetCarbs ?? 300;
    final targetF = profile?.targetFats ?? 67;
    final allHit = p >= targetP * 0.9 && c >= targetC * 0.9 && f >= targetF * 0.9;
    final alreadyPlayed = prefs.getBool('confetti_${DateTime.now().day}_${DateTime.now().month}') ?? false;

    if (mounted) {
      setState(() {
        _name = name;
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
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.stop();
    _animController.dispose();
    super.dispose();
  }

  void _refresh() => _loadAll();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surface,
      body: SafeArea(
        child: ConfettiOverlay(
          show: _showConfetti,
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context, isDark)),
                  SliverToBoxAdapter(child: AnimatedEntrance(delayMs: 50, child: _buildStreakCard(context, isDark))),
                  SliverToBoxAdapter(child: AnimatedEntrance(delayMs: 100, child: _buildCalorieRing(context, isDark))),
                  SliverToBoxAdapter(child: AnimatedEntrance(delayMs: 150, child: _buildMacroBars(context, isDark))),
                  SliverToBoxAdapter(child: AnimatedEntrance(delayMs: 200, child: _buildWeekStrip(context, isDark))),
                  SliverToBoxAdapter(child: AnimatedEntrance(delayMs: 250, child: _buildQuickActions(context, isDark))),
                  SliverToBoxAdapter(child: AnimatedEntrance(delayMs: 300, child: _buildRecentMeals(context, isDark))),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 18
            ? 'Good Afternoon'
            : 'Good Evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(_name.isNotEmpty ? _name : 'MacroSnap',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scans remaining badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (_scansLeft > 0 ? MacroSnapTheme.emerald : MacroSnapTheme.rose).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_scansLeft > 0 ? MacroSnapTheme.emerald : MacroSnapTheme.rose).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on_rounded, size: 14,
                        color: _scansLeft > 0 ? MacroSnapTheme.emerald : MacroSnapTheme.rose),
                    const SizedBox(width: 4),
                    Text(_scansLeft >= 99 ? 'Unlimited' : '$_scansLeft',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: _scansLeft > 0 ? MacroSnapTheme.emerald : MacroSnapTheme.rose)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ScaleOnPress(
                onTap: () => Navigator.push(context, habitFlowRoute(const SettingsScreen())),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? MacroSnapTheme.cardDark : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.settings_rounded, size: 20,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STREAK CARD ───────────────────────────────────────────
  Widget _buildStreakCard(BuildContext context, bool isDark) {
    final isBest = StreakService.isLongestStreak(_streak, _bestStreak);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _glassDecoration(context, isDark),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [MacroSnapTheme.amber, MacroSnapTheme.orange]),
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$_streak',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      const SizedBox(width: 4),
                      Text('day${_streak == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(isBest ? '🔥 New personal best!' : 'Keep the streak going!',
                      style: TextStyle(fontSize: 13,
                          color: isBest ? MacroSnapTheme.emerald : (isDark ? Colors.white38 : const Color(0xFF94A3B8)))),
                ],
              ),
            ),
            // Streak dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(min(_streak, 7), (i) =>
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        MacroSnapTheme.emerald.withOpacity(0.5 + (i / max(_streak, 1)) * 0.5),
                        MacroSnapTheme.emeraldLight,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CALORIE RING ───────────────────────────────────────────
  Widget _buildCalorieRing(BuildContext context, bool isDark) {
    final profile = DietPlanService.instance.profile;
    final targetCal = profile?.targetCalories ?? 2000;
    final consumed = MealStore.instance.todayCalories;
    final progress = (consumed / targetCal).clamp(0.0, 1.0);
    final remaining = max(targetCal - consumed, 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _glassDecoration(context, isDark),
        child: Row(
          children: [
            // Big calorie ring
            SizedBox(
              width: 100, height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: _RingPainter(
                      progress: progress,
                      color: MacroSnapTheme.emerald,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      strokeWidth: 8,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(consumed.toString(),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.1)),
                      Text('kcal',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Daily Goal',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      Text('${targetCal.toStringAsFixed(0)} kcal',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(MacroSnapTheme.emerald),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.arrow_downward_rounded, size: 14,
                          color: MacroSnapTheme.emerald),
                      const SizedBox(width: 4),
                      Text('$remaining kcal remaining',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: MacroSnapTheme.emerald)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MACRO BARS ─────────────────────────────────────────────
  Widget _buildMacroBars(BuildContext context, bool isDark) {
    final p = MealStore.instance.todayProtein;
    final c = MealStore.instance.todayCarbs;
    final f = MealStore.instance.todayFats;
    final profile = DietPlanService.instance.profile;
    final targetP = profile?.targetProtein ?? 150;
    final targetC = profile?.targetCarbs ?? 300;
    final targetF = profile?.targetFats ?? 67;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _glassDecoration(context, isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Macronutrients',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const Spacer(),
                if (p + c + f > 0)
                  Flexible(
                    child: Text(
                      '${(p / max(p + c + f, 1) * 100).round()}% P · ${(c / max(p + c + f, 1) * 100).round()}% C · ${(f / max(p + c + f, 1) * 100).round()}% F',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _macroBar('Protein', p, targetP, MacroSnapTheme.rose, isDark, 'g'),
            const SizedBox(height: 14),
            _macroBar('Carbs', c, targetC, MacroSnapTheme.amber, isDark, 'g'),
            const SizedBox(height: 14),
            _macroBar('Fats', f, targetF, MacroSnapTheme.blue, isDark, 'g'),
          ],
        ),
      ),
    );
  }

  Widget _macroBar(String label, double value, double target, Color color, bool isDark, String unit) {
    final pct = (value / max(target, 1)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B))),
              ],
            ),
            Text('${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}$unit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
          ],
        ),
        const SizedBox(height: 8),
        // Animated progress bar with Habit Flow style
        AnimatedProgressBar(value: pct, color: color, height: 8),
      ],
    );
  }

  // ─── WEEK STRIP ─────────────────────────────────────────────
  Widget _buildWeekStrip(BuildContext context, bool isDark) {
    final meals = MealStore.instance.allMeals;
    final now = DateTime.now();
    final dayMeals = <String, List<MealRecord>>{};
    for (final m in meals) {
      final key = '${m.date.year}-${m.date.month}-${m.date.day}';
      dayMeals.putIfAbsent(key, () => []).add(m);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _glassDecoration(context, isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('This Week',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
                ScaleOnPress(
                  onTap: () async {
                    try {
                      await ShareService.shareWeekSummary();
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MacroSnapTheme.emerald.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.share_rounded, size: 16, color: MacroSnapTheme.emerald),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final d = DateTime(now.year, now.month, now.day - (6 - i));
                final key = '${d.year}-${d.month}-${d.day}';
                final dayList = dayMeals[key] ?? [];
                final logged = dayList.isNotEmpty;
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final isToday = d.day == now.day && d.month == now.month && d.year == now.year;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(days[d.weekday - 1],
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: isToday
                                ? MacroSnapTheme.emerald
                                : (isDark ? Colors.white38 : const Color(0xFF94A3B8)))),
                    const SizedBox(height: 8),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: logged
                            ? MacroSnapTheme.emerald.withOpacity(0.2)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        border: isToday
                            ? Border.all(color: MacroSnapTheme.emerald, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: logged
                            ? Icon(Icons.check_rounded, size: 16, color: MacroSnapTheme.emerald)
                            : Text('${d.day}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (dayList.isNotEmpty)
                      Text('${dayList.fold(0, (s, m) => s + m.calories)}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500,
                              color: MacroSnapTheme.emerald.withOpacity(0.7))),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ─── QUICK ACTIONS ──────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _glassDecoration(context, isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(Icons.camera_alt_rounded, 'Snap', MacroSnapTheme.emerald, isDark, () {
                  Navigator.push(context, habitFlowRoute(const ScanScreen())).then((_) => _refresh());
                }),
                _quickAction(Icons.qr_code_scanner_rounded, 'Barcode', MacroSnapTheme.blue, isDark, () {
                  Navigator.push(context, habitFlowRoute(const BarcodeScanScreen()));
                }),
                _quickAction(Icons.auto_awesome_rounded, 'Diet', MacroSnapTheme.purple, isDark, () {
                  DietPlanService.instance.load().then((_) {
                    Navigator.push(context, habitFlowRoute(const DietPlanScreen()));
                  });
                }),
                _quickAction(Icons.menu_book_rounded, 'Recipes', MacroSnapTheme.rose, isDark, () {
                  Navigator.push(context, habitFlowRoute(const RecipeListScreen()));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, bool isDark, VoidCallback onTap) {
    return ScaleOnPress(
      onTap: onTap,
      scaleAmount: 0.93,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : const Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  // ─── RECENT MEALS ───────────────────────────────────────────
  Widget _buildRecentMeals(BuildContext context, bool isDark) {
    final meals = MealStore.instance.todayMeals;
    if (meals.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _glassDecoration(context, isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Today\'s Meals',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.emerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${meals.fold(0, (s, m) => s + m.calories)} kcal',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: MacroSnapTheme.emerald)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...meals.take(5).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _mealIcon(m).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_mealIconData(m), color: _mealIcon(m), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        Text(m.serving,
                            style: TextStyle(fontSize: 12,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Text('${m.calories}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _mealIcon(MealRecord m) {
    final h = m.date.hour;
    if (h >= 5 && h < 11) return MacroSnapTheme.amber;
    if (h >= 11 && h < 15) return MacroSnapTheme.emerald;
    if (h >= 17 && h < 22) return MacroSnapTheme.blue;
    return MacroSnapTheme.rose;
  }

  IconData _mealIconData(MealRecord m) {
    final h = m.date.hour;
    if (h >= 5 && h < 11) return Icons.wb_sunny_rounded;
    if (h >= 11 && h < 15) return Icons.restaurant_rounded;
    if (h >= 17 && h < 22) return Icons.nights_stay_rounded;
    return Icons.cookie_rounded;
  }

  BoxDecoration _glassDecoration(BuildContext context, bool isDark) {
    return MacroSnapTheme.glassDecoration(context);
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
