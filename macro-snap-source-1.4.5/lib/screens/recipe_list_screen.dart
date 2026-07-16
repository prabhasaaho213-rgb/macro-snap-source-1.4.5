import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../models/recipe.dart';
import '../services/meal_store.dart';
import '../services/recipe_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'recipe_editor_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  @override
  void initState() {
    super.initState();
    RecipeService.instance.addListener(_onChanged);
    RecipeService.instance.load();
  }

  @override
  void dispose() {
    RecipeService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _logRecipe(Recipe recipe) async {
    final servingsCtrl = TextEditingController(text: '1');
    final servings = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Recipe'),
        content: TextField(
          controller: servingsCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Servings eaten'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(servingsCtrl.text) ?? 1),
              child: const Text('Log')),
        ],
      ),
    );
    if (servings == null || servings <= 0) return;

    MealStore.instance.add(MealRecord(
      id: '${recipe.id}_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      name: recipe.name,
      category: 'Recipe',
      calories: (recipe.perServingCalories * servings).round(),
      protein: recipe.perServingProtein * servings,
      carbs: recipe.perServingCarbs * servings,
      fats: recipe.perServingFats * servings,
      fiber: recipe.perServingFiber * servings,
      serving: '$servings serving(s) of ${recipe.name}',
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${recipe.name} logged!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipes = RecipeService.instance.recipes;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Recipes', style: TextStyle(fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context, MaterialPageRoute(builder: (_) => const RecipeEditorScreen()));
          if (result == true) _onChanged();
        },
        backgroundColor: MacroSnapTheme.emerald,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Recipe', style: TextStyle(color: Colors.white)),
      ),
      body: recipes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded, size: 64,
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  Text('No recipes yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  Text('Add your family recipes\nand log them anytime',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14,
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
              itemCount: recipes.length,
              itemBuilder: (ctx, i) => _buildRecipeCard(isDark, recipes[i]),
            ),
    );
  }

  Widget _buildRecipeCard(bool isDark, Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final result = await Navigator.push<bool>(
              context, MaterialPageRoute(
                builder: (_) => RecipeEditorScreen(recipeId: recipe.id)));
            if (result == true) _onChanged();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MacroSnapTheme.emerald.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(recipe.ingredients.length == 1 ? '1 Ingredient' : '${recipe.ingredients.length} Ingredients',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: MacroSnapTheme.emerald)),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete') {
                          await RecipeService.instance.delete(recipe.id);
                          _onChanged();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      icon: Icon(Icons.more_vert_rounded, size: 20,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(recipe.name, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Text('${recipe.servings} servings Â· ${recipe.perServingCalories.toStringAsFixed(0)} cal/serving',
                    overflow: TextOverflow.ellipsis, maxLines: 1,
                    style: TextStyle(fontSize: 13,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniMacro('P', recipe.perServingProtein, MacroSnapTheme.rose),
                    const SizedBox(width: 12),
                    _miniMacro('C', recipe.perServingCarbs, MacroSnapTheme.amber),
                    const SizedBox(width: 12),
                    _miniMacro('F', recipe.perServingFats, MacroSnapTheme.blue),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Log Meal',
                    onPressed: () => _logRecipe(recipe),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniMacro(String label, double value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ${value.toStringAsFixed(1)}g',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
