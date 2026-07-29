import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../services/gemini_service.dart';
import '../services/local_analyzer.dart';
import '../services/meal_store.dart';
import '../widgets/animations.dart';
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
  String _analysisStage = 'Analyzing your meal...';
  String _analysisSub = 'Our AI is identifying each dish\nand calculating nutrition';

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
    _animateStages();
  }

  void _animateStages() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isAnalyzing) {
        setState(() {
          _analysisStage = 'Still working...';
          _analysisSub = 'Food identification may take a moment\nfor complex dishes';
        });
      }
    });
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isAnalyzing) {
        setState(() {
          _analysisStage = 'Taking longer than expected';
          _analysisSub = 'The server may be busy. You can retry or use local analysis.';
        });
      }
    });
  }

  Future<void> _analyze() async {
    // Try Gemini AI first
    if (GeminiService.hasServerUrl) {
      try {
        final result = await GeminiService.analyzeFoodImage(widget.imagePath);
        if (mounted) {
          setState(() { _result = result; _isAnalyzing = false; });
          _animController.forward();
        }
        return;
      } catch (_) {
        // Fall through to local fallback
      }
    }

    // Fallback: Local ML Kit analysis
    try {
      final localResult = await LocalAnalyzer.analyze(widget.imagePath);
      if (mounted) {
        if (localResult.bestMatch != null) {
          final item = localResult.bestMatch!;
          final dish = DishItem(
            name: item.name,
            portionDescription: 'Local estimate',
            caloriesPer100g: item.calories,
            proteinPer100g: item.protein,
            carbsPer100g: item.carbs,
            fatsPer100g: item.fats,
            fiberPer100g: item.fiber,
            sugarPer100g: 0,
            suitableFor: 'both',
          );
          final result = NutritionResult(
            dishes: [dish],
            description: 'On-device analysis (${localResult.labels.take(2).join(", ")})',
            confidence: 0.5,
          );
          setState(() { _result = result; _isAnalyzing = false; });
        } else {
          setState(() { _error = 'Could not identify food. Try a clearer photo.'; _isAnalyzing = false; });
        }
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Analysis failed: ${e.toString()}'; _isAnalyzing = false; });
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
                color: MacroSnapTheme.textTertiary(context)),
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
                  color: MacroSnapTheme.neonGreen.withValues(alpha:  0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.remove_rounded, size: 18, color: MacroSnapTheme.neonGreen),
              ),
            ),
            const SizedBox(width: 12),
            Text('$_grams',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const SizedBox(width: 4),
            Text('g',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: MacroSnapTheme.textTertiary(context))),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _grams = _grams <= 975 ? _grams + 25 : 1000),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MacroSnapTheme.neonGreen.withValues(alpha:  0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded, size: 18, color: MacroSnapTheme.neonGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(bool isDark, NutritionResult r) async {
    final calCtrl = TextEditingController(text: r.calories.toString());
    final proCtrl = TextEditingController(text: r.protein.toStringAsFixed(1));
    final carbCtrl = TextEditingController(text: r.carbs.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: r.fats.toStringAsFixed(1));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? MacroSnapTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit Nutrition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories (kcal)', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: proCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein (g)', border: OutlineInputBorder(), isDense: true),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: carbCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs (g)', border: OutlineInputBorder(), isDense: true),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: fatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fats (g)', border: OutlineInputBorder(), isDense: true),
                )),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final cal = int.tryParse(calCtrl.text) ?? r.calories;
              final pro = double.tryParse(proCtrl.text) ?? r.protein;
              final carb = double.tryParse(carbCtrl.text) ?? r.carbs;
              final fat = double.tryParse(fatCtrl.text) ?? r.fats;
              setState(() {
                _result = NutritionResult(
                  dishes: r.dishes,
                  description: r.description,
                  confidence: r.confidence,
                  grams: r.grams,
                );
                // Override the computed values by modifying dishes
                if (r.dishes.isNotEmpty) {
                  final ratio = (r.grams > 0 ? r.grams : 100) / 100.0;
                  final d = r.dishes.first;
                  final adjustedDish = DishItem(
                    name: d.name,
                    portionDescription: d.portionDescription,
                    caloriesPer100g: ((cal / ratio) / r.dishes.length).round(),
                    proteinPer100g: (pro / ratio) / r.dishes.length,
                    carbsPer100g: (carb / ratio) / r.dishes.length,
                    fatsPer100g: (fat / ratio) / r.dishes.length,
                    fiberPer100g: d.fiberPer100g,
                    sugarPer100g: d.sugarPer100g,
                    suitableFor: d.suitableFor,
                  );
                  final adjustedDishes = [adjustedDish, ...r.dishes.sublist(1)];
                  _result = NutritionResult(
                    dishes: adjustedDishes,
                    description: r.description + ' (edited)',
                    confidence: r.confidence,
                    grams: r.grams,
                  );
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    calCtrl.dispose();
    proCtrl.dispose();
    carbCtrl.dispose();
    fatCtrl.dispose();
  }

  @override
  void dispose() {
    _animController.stop();
    _animController.dispose();
    // Clean up temp image file
    try {
      final file = File(widget.imagePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A), size: 24),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(
          _isAnalyzing ? 'Analyzing...' : _error != null ? 'Error' : 'Results',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: SafeArea(
          child: _isAnalyzing
              ? _buildLoadingState(isDark)
              : _error != null
                  ? _buildError(isDark)
                  : _buildResults(isDark),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return ShimmerLoading(
      isLoading: true,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Image skeleton
            const SkeletonPlaceholder(height: 220),
            const SizedBox(height: 12),

            // Gram adjuster skeleton
            const SkeletonPlaceholder(height: 40),
            const SizedBox(height: 16),

            // Nutrition card skeleton
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Header badge skeleton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SkeletonPlaceholder(width: 100, height: 28, borderRadius: 14),
                      const SkeletonPlaceholder(width: 100, height: 28, borderRadius: 14),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Calories skeleton
                  const SkeletonPlaceholder(width: 100, height: 60, borderRadius: 8),
                  const SizedBox(height: 16),
                  // Macro circles row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(3, (_) =>
                      const SkeletonPlaceholder(width: 56, height: 56, isCircle: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nutrition details skeleton
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  SkeletonPlaceholder(width: 150, height: 20, borderRadius: 4),
                  SizedBox(height: 20),
                  SkeletonPlaceholder(height: 16, borderRadius: 4),
                  SizedBox(height: 16),
                  SkeletonPlaceholder(height: 16, borderRadius: 4),
                  SizedBox(height: 16),
                  SkeletonPlaceholder(height: 16, borderRadius: 4),
                  SizedBox(height: 16),
                  SkeletonPlaceholder(height: 16, borderRadius: 4),
                  SizedBox(height: 16),
                  SkeletonPlaceholder(height: 16, borderRadius: 4),
                  SizedBox(height: 16),
                  SkeletonPlaceholder(height: 16, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Analysis stage text below skeletons
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    _analysisStage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _analysisSub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: MacroSnapTheme.textTertiary(context),
                        height: 1.5,
                      ),
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
                color: (isNoUrl ? MacroSnapTheme.macroCalories : MacroSnapTheme.macroProtein).withValues(alpha:  0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isNoUrl ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                color: isNoUrl ? MacroSnapTheme.macroCalories : MacroSnapTheme.macroProtein,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isNoUrl ? 'Server Not Set' : 'Analysis Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
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
                    color: MacroSnapTheme.textTertiary(context),
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
            child: Hero(
              tag: 'food_image_${widget.imagePath}',
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
                    color: MacroSnapTheme.neonGreen,
                  ),
                  label: Text(
                    _showPerDish ? 'Show Totals' : 'Show per Dish',
                    style: const TextStyle(fontSize: 13, color: MacroSnapTheme.neonGreen),
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
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildNutrientRow('Calories', r.calories, 'kcal', MacroSnapTheme.macroCalories, isDark),
                        _buildNutrientRow('Protein', r.protein, 'g', MacroSnapTheme.macroProtein, isDark),
                        _buildNutrientRow('Carbs', r.carbs, 'g', MacroSnapTheme.macroCalories, isDark),
                        _buildNutrientRow('Sugar', r.sugar, 'g', const Color(0xFFDB2777), isDark),
                        _buildNutrientRow('Fats', r.fats, 'g', MacroSnapTheme.macroFats, isDark),
                        _buildNutrientRow('Fiber', r.fiber, 'g', MacroSnapTheme.neonGreen, isDark),
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
                              color: MacroSnapTheme.neonGreen.withValues(alpha:  0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: MacroSnapTheme.neonGreen, size: 24),
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
                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(r.confidence * 100).round()}% confidence Â· ${r.description}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: MacroSnapTheme.textTertiary(context),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditDialog(isDark, r),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MacroSnapTheme.neonGreen,
                          side: BorderSide(color: MacroSnapTheme.neonGreen.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GradientButton(
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
                    ),
                  ],
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
    final badgeColor = isBulk ? MacroSnapTheme.macroFats : isDiet ? MacroSnapTheme.macroProtein : MacroSnapTheme.neonGreen;
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
                        color: MacroSnapTheme.neonGreen.withValues(alpha:  0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        dish.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: MacroSnapTheme.neonGreen,
                        ),
                      ),
                    ),
                  ),
                  if (dish.portionDescription.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(dish.portionDescription,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: MacroSnapTheme.textTertiary(context))),
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
                  _buildDishMacro('P', (dish.proteinPer100g * ratio), MacroSnapTheme.macroProtein, isDark),
                  _buildDishMacro('C', (dish.carbsPer100g * ratio), MacroSnapTheme.macroCalories, isDark),
                  _buildDishMacro('F', (dish.fatsPer100g * ratio), MacroSnapTheme.macroFats, isDark),
                  _buildDishMacro('Fib', (dish.fiberPer100g * ratio), MacroSnapTheme.neonGreen, isDark),
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
                color: MacroSnapTheme.textTertiary(context))),
      ],
    );
  }

  Widget _buildMealHeader(bool isDark, NutritionResult r) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: MacroSnapTheme.neonGreen.withValues(alpha:  0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            r.dishes.length == 1 ? r.dishes.first.name : '${r.dishes.length} Items',
            style: const TextStyle(
              color: MacroSnapTheme.neonGreen,
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
    final color = isBulk ? MacroSnapTheme.macroFats : isDiet ? MacroSnapTheme.macroProtein : MacroSnapTheme.neonGreen;
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
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
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
            color: MacroSnapTheme.textTertiary(context),
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
        _buildMacroItem('Protein', '${r.protein.toInt()}g', MacroSnapTheme.macroProtein, isDark),
        _buildMacroItem('Carbs', '${r.carbs.toInt()}g', MacroSnapTheme.macroCalories, isDark),
        _buildMacroItem('Fats', '${r.fats.toInt()}g', MacroSnapTheme.macroFats, isDark),
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
              color: MacroSnapTheme.textPrimaryMuted(context),
            ),
          ),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(value is int ? 0 : 1)} $unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
