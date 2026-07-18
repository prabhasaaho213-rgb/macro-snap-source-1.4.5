import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../services/meal_store.dart';
import 'package:macro_snap/services/food_database.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'add_meal_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: IndexedStack(
            index: _currentIndex,
            children: const [
              HomeScreen(),
              ScanScreen(),
              _MealsTab(),
              SettingsScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.camera_alt_rounded,
                label: 'Scan',
                isSelected: _currentIndex == 1,
                isScan: true,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.restaurant_rounded,
                label: 'Meals',
                isSelected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isScan;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isScan = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isScan) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isSelected
                ? const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight])
                : LinearGradient(
                    colors: [
                      (isDark ? Colors.white : MacroSnapTheme.emerald).withOpacity(0.1),
                      (isDark ? Colors.white : MacroSnapTheme.emerald).withOpacity(0.05),
                    ],
                  ),
            border: Border.all(
              color: isSelected
                  ? MacroSnapTheme.emeraldLight
                  : (isDark ? Colors.white : MacroSnapTheme.emerald).withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white54 : MacroSnapTheme.emerald.withOpacity(0.6)),
            size: 24,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? MacroSnapTheme.emerald.withOpacity(0.15) : MacroSnapTheme.emerald.withOpacity(0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? MacroSnapTheme.emerald
                  : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MacroSnapTheme.emerald,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealsTab extends StatefulWidget {
  const _MealsTab();

  @override
  State<_MealsTab> createState() => _MealsTabState();
}

class _MealsTabState extends State<_MealsTab> {
  @override
  void initState() {
    super.initState();
    MealStore.instance.changeNotifier.addListener(_onMealsChanged);
  }

  @override
  void dispose() {
    MealStore.instance.changeNotifier.removeListener(_onMealsChanged);
    super.dispose();
  }

  void _onMealsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meals = MealStore.instance.todayMeals;
    final totalCals = meals.fold<int>(0, (s, m) => s + m.calories);
    final mealsByTime = _groupByTime(meals);

    return Scaffold(
      backgroundColor: isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surface,
      appBar: AppBar(
        title: Text('My Meals', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
            onPressed: () async {
              final item = await Navigator.push<FoodItem>(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              if (item != null && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddMealScreen(food: item)),
                );
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
      body: meals.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_rounded, size: 64, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  Text('No meals logged yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white30 : const Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  Text('Snap a photo or search food!', style: TextStyle(fontSize: 14, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await MealStore.instance.load();
                if (mounted) setState(() {});
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  _buildTotalCard(context, totalCals, meals.length, isDark),
                  const SizedBox(height: 20),
                  ...mealsByTime.entries.map((e) => _buildMealGroup(e.key, e.value, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalCard(BuildContext context, int cals, int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MacroSnapTheme.glassDecoration(context),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$cals kcal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text('$count meal${count == 1 ? '' : 's'} today', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealGroup(String name, List<MealRecord> meals, bool isDark) {
    final groupIcons = {
      'Breakfast': Icons.wb_sunny_rounded,
      'Lunch': Icons.restaurant_rounded,
      'Dinner': Icons.nights_stay_rounded,
      'Snacks': Icons.cookie_rounded,
    };
    final groupColors = {
      'Breakfast': MacroSnapTheme.amber,
      'Lunch': MacroSnapTheme.emerald,
      'Dinner': MacroSnapTheme.blue,
      'Snacks': MacroSnapTheme.rose,
    };
    final cals = meals.fold<int>(0, (s, m) => s + m.calories);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: MacroSnapTheme.glassDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(groupIcons[name], color: groupColors[name], size: 18),
                const SizedBox(width: 8),
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                const Spacer(),
                Text('$cals kcal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 12),
            ...meals.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: groupColors[name]!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(groupIcons[name], color: groupColors[name], size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text(m.serving, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                    ],
                  )),
                  Text('${m.calories}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Map<String, List<MealRecord>> _groupByTime(List<MealRecord> meals) {
    final grouped = <String, List<MealRecord>>{
      'Breakfast': [], 'Lunch': [], 'Dinner': [], 'Snacks': [],
    };
    for (final m in meals) {
      final h = m.date.hour;
      if (h >= 5 && h < 11) grouped['Breakfast']!.add(m);
      else if (h >= 11 && h < 15) grouped['Lunch']!.add(m);
      else if (h >= 17 && h < 22) grouped['Dinner']!.add(m);
      else grouped['Snacks']!.add(m);
    }
    grouped.removeWhere((k, v) => v.isEmpty);
    return grouped;
  }
}
