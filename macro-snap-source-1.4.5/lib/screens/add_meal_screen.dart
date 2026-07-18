import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../services/food_database.dart';
import '../services/meal_store.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class AddMealScreen extends StatelessWidget {
  final FoodItem food;

  const AddMealScreen({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Log Meal'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: MacroSnapTheme.emerald.withValues(alpha:  0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              food.category[0],
                              style: const TextStyle(
                                color: MacroSnapTheme.emerald,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${food.serving} Â· ${food.category}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildTotalCalories(isDark),
                    const SizedBox(height: 24),
                    _buildMacroRow(isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRow('Calories', '${food.calories} kcal', MacroSnapTheme.amber, isDark),
                    _buildRow('Protein', '${food.protein}g', MacroSnapTheme.rose, isDark),
                    _buildRow('Carbs', '${food.carbs}g', MacroSnapTheme.amber, isDark),
                    _buildRow('Fats', '${food.fats}g', MacroSnapTheme.blue, isDark),
                    _buildRow('Fiber', '${food.fiber}g', MacroSnapTheme.emerald, isDark),
                  ],
                ),
              ),
              const Spacer(),
              GradientButton(
                label: 'Log This Meal',
                onPressed: () {
                  MealStore.instance.add(MealRecord(
                    id: const Uuid().v4(),
                    date: DateTime.now(),
                    name: food.name,
                    category: food.category,
                    calories: food.calories,
                    protein: food.protein,
                    carbs: food.carbs,
                    fats: food.fats,
                    fiber: food.fiber,
                    serving: food.serving,
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Meal logged!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCalories(bool isDark) {
    return Column(
      children: [
        Text(
          '${food.calories}',
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

  Widget _buildMacroRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMacroItem('Protein', '${food.protein.toInt()}g', MacroSnapTheme.rose, isDark),
        _buildMacroItem('Carbs', '${food.carbs.toInt()}g', MacroSnapTheme.amber, isDark),
        _buildMacroItem('Fats', '${food.fats.toInt()}g', MacroSnapTheme.blue, isDark),
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF475569))),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

