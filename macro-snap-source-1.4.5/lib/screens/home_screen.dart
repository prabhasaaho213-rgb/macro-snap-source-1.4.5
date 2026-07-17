import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../services/meal_store.dart';
import '../models/meal_record.dart';
import '../services/update_checker.dart';
import '../services/scan_gate.dart';
import '../services/streak_service.dart';
import '../models/diet_profile.dart';
import 'diet_plan_screen.dart';
import '../widgets/glass_card.dart';
import '../widgets/macro_ring.dart';
import 'package:macro_snap/services/food_database.dart';
import 'add_meal_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'recipe_list_screen.dart';
import 'barcode_scan_screen.dart';
import '../services/share_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  String _avatar = '😎';
  String _name = '';
  int _streak = 0;
  int _bestStreak = 0;
  int _scansLeft = 3;
  List<_DaySummary> _weekSummary = [];

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
    UpdateChecker.checkAndPrompt(context);
  }

  Future<void> _loadAll() async {
    await MealStore.instance.load();
    await DietPlanService.instance.load();
    final p = DietPlanService.instance.profile;
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString('name') ?? '';
    final phone = prefs.getString('phone') ?? '';
    final isPlaceholder = name.isEmpty || name == phone || name.startsWith('guest_') || RegExp(r'^\+?[0-9]+$').hasMatch(name);
    if (isPlaceholder) {
      final newName = await _promptName();
      if (newName != null && newName.isNotEmpty) {
        await prefs.setString('name', newName);
        name = newName;
      }
    }
    await StreakService.checkAndUpdate();
    final streak = await StreakService.getCurrent();
    final best = await StreakService.getBest();
    final scans = await ScanGate.getScansRemaining();
    _computeWeekSummary();
    if (mounted) {
      setState(() {
        _avatar = p?.avatar ?? '😎';
        _name = name;
        _streak = streak;
        _bestStreak = best;
        _scansLeft = scans;
      });
      _animController.forward();
    }
  }

  Future<String?> _promptName() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('What should we call you?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 15,
          decoration: const InputDecoration(
            hintText: 'Your name (max 15 chars)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return name;
  }

  void _computeWeekSummary() {
    final meals = MealStore.instance.allMeals;
    if (meals.isEmpty) { _weekSummary = []; return; }

    final now = DateTime.now();
    final dayMeals = <String, List<MealRecord>>{};
    for (final m in meals) {
      final day = '${m.date.year}-${m.date.month}-${m.date.day}';
      dayMeals.putIfAbsent(day, () => <MealRecord>[]).add(m);
    }

    _weekSummary = [];
    for (int i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day - (6 - i));
      final key = '${d.year}-${d.month}-${d.day}';
      final dayList = dayMeals[key] ?? [];
      final protein = dayList.fold(0.0, (s, m) => s + m.protein);
      final calories = dayList.fold(0, (s, m) => s + m.calories);
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      _weekSummary.add(_DaySummary(
        label: days[d.weekday - 1],
        date: d,
        protein: protein,
        calories: calories,
        mealCount: dayList.length,
      ));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _refresh() => _loadAll();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, isDark)),
                SliverToBoxAdapter(child: _buildStreakRow(isDark)),
                if (_weekSummary.isNotEmpty)
                  SliverToBoxAdapter(child: _buildWeekInsights(context, isDark)),
                SliverToBoxAdapter(child: _buildCalorieCard(context, isDark)),
                SliverToBoxAdapter(child: _buildMacrosSection(context, isDark)),
                SliverToBoxAdapter(child: _buildQuickActions(context, isDark)),
                SliverToBoxAdapter(child: _buildRecentMeals(context, isDark)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[now.weekday - 1];
    final targetCal = DietPlanService.instance.profile?.targetCalories ?? 2000;
    final caloriesToday = MealStore.instance.todayCalories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good ${now.hour < 12 ? 'Morning' : now.hour < 18 ? 'Afternoon' : 'Evening'},',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _name.isNotEmpty ? '$_name' : 'MacroSnap User',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$dayName · ${now.day}/${now.month}/${now.year}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Today’s progress',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.settings_rounded, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMiniStat('Streak', '$_streak', Icons.local_fire_department_rounded, MacroSnapTheme.amber, isDark),
                    _buildMiniStat('Scans', _scansLeft >= 99 ? 'Pro' : '$_scansLeft', Icons.flash_on_rounded, _scansLeft > 0 ? MacroSnapTheme.emerald : MacroSnapTheme.rose, isDark),
                    _buildMiniStat('Target', '${targetCal.toStringAsFixed(0)} kcal', Icons.track_changes_rounded, MacroSnapTheme.blue, isDark),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '$caloriesToday / ${targetCal.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: (caloriesToday / targetCal).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(MacroSnapTheme.emerald),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Build momentum by logging a meal or scanning a food item.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakRow(bool isDark) {
    if (_streak <= 0) return const SizedBox.shrink();
    final isBest = StreakService.isLongestStreak(_streak, _bestStreak);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department_rounded,
                color: MacroSnapTheme.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_streak day${_streak == 1 ? '' : 's'} streak',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(
                    isBest ? 'New personal best!' : 'Keep the streak going',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(min(_streak, 7), (i) =>
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MacroSnapTheme.emerald.withOpacity(0.6 + (i / max(_streak, 1) * 0.4)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildWeekInsights(BuildContext context, bool isDark) {
    final profile = DietPlanService.instance.profile;
    if (_weekSummary.isEmpty) return const SizedBox.shrink();

    final daysBelowProtein = _weekSummary.where((d) =>
        d.mealCount > 0 && profile != null && d.protein < profile.targetProtein * 0.8).length;
    final daysBelowCals = _weekSummary.where((d) =>
        d.mealCount > 0 && profile != null && d.calories < profile.targetCalories * 0.85).length;
    final daysLogged = _weekSummary.where((d) => d.mealCount > 0).length;

    List<String> insights = [];
    if (daysLogged == 0) return const SizedBox.shrink();
    if (daysBelowProtein >= 4 && profile != null) {
      insights.add('Protein was 20%+ below target on $daysBelowProtein of the last 7 days');
    }
    if (daysBelowCals >= 4 && profile != null) {
      insights.add('Calories were below target on $daysBelowCals of the last 7 days');
    }
    if (daysBelowProtein == 0 && daysLogged >= 5) {
      insights.add('Great consistency — hitting protein targets all week!');
    }
    if (daysLogged >= 6) {
      insights.add('Logged meals $daysLogged/7 days this week. Keep it up!');
    }
    if (insights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: MacroSnapTheme.emerald, size: 20),
                const SizedBox(width: 8),
                Text('Weekly Insights',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B))),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ShareService.shareWeekSummary();
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString()),
                            behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MacroSnapTheme.emerald.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.share_rounded, size: 18, color: MacroSnapTheme.emerald),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MacroSnapTheme.emerald.withOpacity( 0.6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(insight, style: TextStyle(fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF475569),
                        height: 1.4)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieCard(BuildContext context, bool isDark) {
    final profile = DietPlanService.instance.profile;
    final targetCal = profile?.targetCalories ?? 2000;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: GlassCard(
        height: 190,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MacroSnapTheme.emerald.withOpacity( isDark ? 0.05 : 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          color: MacroSnapTheme.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Daily Calories',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        MealStore.instance.todayCalories > 0
                            ? '${MealStore.instance.todayCalories}'
                            : '0',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '/ ${targetCal.toStringAsFixed(0)} kcal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (MealStore.instance.todayCalories / targetCal).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(MacroSnapTheme.emerald),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosSection(BuildContext context, bool isDark) {
    final p = MealStore.instance.todayProtein;
    final c = MealStore.instance.todayCarbs;
    final f = MealStore.instance.todayFats;
    final total = p + c + f;
    final profile = DietPlanService.instance.profile;
    final targetProtein = profile?.targetProtein ?? 150;
    final targetCarbs = profile?.targetCarbs ?? 300;
    final targetFats = profile?.targetFats ?? 67;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Macronutrients',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (total > 0)
                  Flexible(
                    child: Text(
                      '${(p / max(total, 1) * 100).round()}% P · ${(c / max(total, 1) * 100).round()}% C · ${(f / max(total, 1) * 100).round()}% F',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MacroRing(
                  progress: (p / targetProtein).clamp(0.0, 1.0),
                  value: p,
                  target: targetProtein,
                  label: 'Protein',
                  color: MacroSnapTheme.rose,
                ),
                MacroRing(
                  progress: (c / targetCarbs).clamp(0.0, 1.0),
                  value: c,
                  target: targetCarbs,
                  label: 'Carbs',
                  color: MacroSnapTheme.amber,
                ),
                MacroRing(
                  progress: (f / targetFats).clamp(0.0, 1.0),
                  value: f,
                  target: targetFats,
                  label: 'Fats',
                  color: MacroSnapTheme.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Snap & Track',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) => const ScanScreen(),
                          transitionsBuilder: (_, a, _, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.search_rounded,
                    label: 'Search Food',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.amber, Color(0xFFFBBF24)],
                    ),
                    onTap: () async {
                      final item = await Navigator.push<FoodItem>(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                      if (item != null && context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMealScreen(food: item),
                          ),
                        );
                      }
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Diet Plan',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                    ),
                    onTap: () async {
                      await DietPlanService.instance.load();
                      if (context.mounted) {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const DietPlanScreen()));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.menu_book_rounded,
                    label: 'Recipes',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.blue, Color(0xFF60A5FA)],
                    ),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipeListScreen()));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan Barcode',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.amber, Color(0xFFFBBF24)],
                    ),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScanScreen()));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMeals(BuildContext context, bool isDark) {
    final meals = MealStore.instance.todayMeals;
    final totalCals = meals.fold<int>(0, (s, m) => s + m.calories);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Meals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                if (meals.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MacroSnapTheme.emerald.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalCals kcal total',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MacroSnapTheme.emerald),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (meals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.restaurant_rounded, size: 48, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),
                      Text(
                        'No meals logged today',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Snap a photo or search food!',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...meals.take(10).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MacroSnapTheme.emerald.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: MacroSnapTheme.emerald, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            '${m.category.isNotEmpty ? '${m.category} Â· ' : ''}${m.serving}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${m.calories} kcal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _DaySummary {
  final String label;
  final DateTime date;
  final double protein;
  final int calories;
  final int mealCount;
  _DaySummary({required this.label, required this.date, required this.protein, required this.calories, required this.mealCount});
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity( 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

