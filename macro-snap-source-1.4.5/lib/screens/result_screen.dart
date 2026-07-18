import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../services/gemini_service.dart';
import '../services/meal_store.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;

  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isAnalyzing = true;
  String? _error;
  NutritionResult? _result;
  int _grams = 100;
  bool _showPerDish = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _analyze();
  }

  Future<void> _analyze() async {
    if (!GeminiService.hasServerUrl) {
      if (mounted) {
        setState(() { _error = 'no_url'; _isAnalyzing = false; });
        _animController.forward();
      }
      return;
    }

    try {
      final result = await GeminiService.analyzeFoodImage(widget.imagePath);
      if (mounted) {
        setState(() { _result = result; _isAnalyzing = false; });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isAnalyzing = false; });
        _animController.forward();
      }
    }
  }

  Widget _buildGramAdjuster(bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.scale_rounded, size: 18,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Total Serving', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B))),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _grams = _grams >= 50 ? _grams - 25 : 25),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MacroSnapTheme.emerald.withValues(alpha:  0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.remove_rounded, size: 18, color: MacroSnapTheme.emerald),
              ),
            ),
            const SizedBox(width: 12),
            Text('$_grams',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(width: 4),
            Text('g',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _grams = _grams <= 975 ? _grams + 25 : 1000),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MacroSnapTheme.emerald.withValues(alpha:  0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded, size: 18, color: MacroSnapTheme.emerald),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isAnalyzing ? 'Analyzing...' : _error != null ? 'Error' : 'Results',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
      body: SafeArea(
        child: _isAnalyzing
            ? _buildLoadingState(isDark)
            : _error != null
                ? _buildError(isDark)
                : _buildResults(isDark),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: MacroSnapTheme.emerald,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your meal...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Our AI is identifying each dish\nand calculating nutrition',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    final isNoUrl = _error == 'no_url';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isNoUrl ? MacroSnapTheme.amber : MacroSnapTheme.rose).withValues(alpha:  0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isNoUrl ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                color: isNoUrl ? MacroSnapTheme.amber : MacroSnapTheme.rose,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isNoUrl ? 'Server Not Set' : 'Analysis Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  isNoUrl
                      ? 'Enter your server URL in Settings\nto enable AI food analysis.'
                      : _error ?? 'Something went wrong.\nPlease try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isNoUrl)
              GradientButton(
                label: 'Go Back',
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final r = _result!;
    final hasMultiDish = r.dishes.length > 1;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                File(widget.imagePath),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildGramAdjuster(isDark),
          if (hasMultiDish) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _showPerDish = !_showPerDish),
                  icon: Icon(
                    _showPerDish ? Icons.view_agenda_rounded : Icons.dashboard_rounded,
                    size: 16,
                    color: MacroSnapTheme.emerald,
                  ),
                  label: Text(
                    _showPerDish ? 'Show Totals' : 'Show per Dish',
                    style: const TextStyle(fontSize: 13, color: MacroSnapTheme.emerald),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                if (_showPerDish && hasMultiDish)
                  ...r.dishes.map((d) => _buildDishCard(isDark, d, r.grams)),
                GlassCard(
                  child: Column(
                    children: [
                      _buildMealHeader(isDark, r),
                      const Divider(height: 32),
                      _buildTotalCalories(isDark, r),
                      const SizedBox(height: 24),
                      _buildMacroRow(isDark, r),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animController,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
                  )),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutrition Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildNutrientRow('Calories', r.calories, 'kcal', MacroSnapTheme.amber, isDark),
                        _buildNutrientRow('Protein', r.protein, 'g', MacroSnapTheme.rose, isDark),
                        _buildNutrientRow('Carbs', r.carbs, 'g', MacroSnapTheme.amber, isDark),
                        _buildNutrientRow('Sugar', r.sugar, 'g', const Color(0xFFDB2777), isDark),
                        _buildNutrientRow('Fats', r.fats, 'g', MacroSnapTheme.blue, isDark),
                        _buildNutrientRow('Fiber', r.fiber, 'g', MacroSnapTheme.emerald, isDark),
                      ],
                    ),
                  ),
                ),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animController,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                    )),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: MacroSnapTheme.emerald.withValues(alpha:  0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: MacroSnapTheme.emerald, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Breakdown (${r.dishes.length} item${r.dishes.length > 1 ? 's' : ''})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(r.confidence * 100).round()}% confidence Â· ${r.description}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Log This Meal',
                  onPressed: () {
                    final combinedName = hasMultiDish
                        ? r.dishes.map((d) => d.name).join(', ')
                        : r.dishes.first.name;
                    MealStore.instance.add(MealRecord(
                      id: const Uuid().v4(),
                      date: DateTime.now(),
                      name: combinedName,
                      category: '',
                      calories: r.calories,
                      protein: r.protein,
                      carbs: r.carbs,
                      fats: r.fats,
                      fiber: r.fiber,
                      serving: r.description,
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(hasMultiDish
                            ? '${r.dishes.length} dishes logged!'
                            : 'Meal logged!'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(bool isDark, DishItem dish, int totalGrams) {
    final ratio = totalGrams / 100;
    final isBulk = dish.suitableFor == 'bulk';
    final isDiet = dish.suitableFor == 'diet';
    final badgeColor = isBulk ? MacroSnapTheme.blue : isDiet ? MacroSnapTheme.rose : MacroSnapTheme.emerald;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MacroSnapTheme.emerald.withValues(alpha:  0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        dish.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: MacroSnapTheme.emerald,
                        ),
                      ),
                    ),
                  ),
                  if (dish.portionDescription.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(dish.portionDescription,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha:  0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(dish.caloriesPer100g * ratio).round()} kcal',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDishMacro('P', (dish.proteinPer100g * ratio), MacroSnapTheme.rose, isDark),
                  _buildDishMacro('C', (dish.carbsPer100g * ratio), MacroSnapTheme.amber, isDark),
                  _buildDishMacro('F', (dish.fatsPer100g * ratio), MacroSnapTheme.blue, isDark),
                  _buildDishMacro('Fib', (dish.fiberPer100g * ratio), MacroSnapTheme.emerald, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDishMacro(String label, double value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value > 0 ? '${value.toStringAsFixed(1)}g' : 'â€”',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildMealHeader(bool isDark, NutritionResult r) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: MacroSnapTheme.emerald.withValues(alpha:  0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            r.dishes.length == 1 ? r.dishes.first.name : '${r.dishes.length} Items',
            style: const TextStyle(
              color: MacroSnapTheme.emerald,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        _buildSuitabilityBadge(isDark, r),
      ],
    );
  }

  Widget _buildSuitabilityBadge(bool isDark, NutritionResult r) {
    final isBulk = r.suitableFor == 'bulk';
    final isDiet = r.suitableFor == 'diet';
    final color = isBulk ? MacroSnapTheme.blue : isDiet ? MacroSnapTheme.rose : MacroSnapTheme.emerald;
    final icon = isBulk ? Icons.fitness_center_rounded : isDiet ? Icons.eco_rounded : Icons.check_circle_rounded;
    final label = isBulk ? 'Best for Bulk' : isDiet ? 'Best for Diet' : 'Balanced';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha:  0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCalories(bool isDark, NutritionResult r) {
    return Column(
      children: [
        Text(
          '${r.calories}',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -2,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'kilocalories',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroRow(bool isDark, NutritionResult r) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMacroItem('Protein', '${r.protein.toInt()}g', MacroSnapTheme.rose, isDark),
        _buildMacroItem('Carbs', '${r.carbs.toInt()}g', MacroSnapTheme.amber, isDark),
        _buildMacroItem('Fats', '${r.fats.toInt()}g', MacroSnapTheme.blue, isDark),
      ],
    );
  }

  Widget _buildMacroItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha:  0.1),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(String label, num value, String unit, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(value is int ? 0 : 1)} $unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
