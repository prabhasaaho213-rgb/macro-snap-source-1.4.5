import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';

class RecipeService extends ChangeNotifier {
  static final RecipeService instance = RecipeService._();
  RecipeService._();

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('recipes');
      if (data != null && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          _recipes = decoded
              .whereType<Map<String, dynamic>>()
              .map((r) => Recipe.fromJson(r))
              .toList();
        }
      }
    } catch (_) {
      _recipes = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recipes', jsonEncode(_recipes.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  Future<String> add(String name, int servings, List<RecipeIngredient> ingredients) async {
    final id = const Uuid().v4();
    _recipes.add(Recipe(id: id, name: name, servings: servings, ingredients: ingredients));
    await _save();
    return id;
  }

  Future<void> update(String id, String name, int servings, List<RecipeIngredient> ingredients) async {
    final idx = _recipes.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _recipes[idx].name = name;
      _recipes[idx].servings = servings;
      _recipes[idx].ingredients = ingredients;
      await _save();
    }
  }

  Future<void> delete(String id) async {
    _recipes.removeWhere((r) => r.id == id);
    await _save();
  }

  Recipe? getById(String id) {
    try {
      return _recipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}