import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'food_database.dart';

class LocalAnalysisResult {
  final FoodItem? bestMatch;
  final List<String> labels;
  final List<FoodItem> candidates;

  LocalAnalysisResult({this.bestMatch, required this.labels, required this.candidates});
}

class LocalAnalyzer {
  static final _labeler = ImageLabeler(
    options: ImageLabelerOptions(
      confidenceThreshold: 0.5,
    ),
  );

  static final Map<String, String> _foodAliases = {
    'bread': 'Roti (1 pc)',
    'roti': 'Roti (1 pc)',
    'naan': 'Naan (1 pc)',
    'rice': 'Steamed Rice (1 plate)',
    'curry': 'Mixed Vegetable Curry',
    'dal': 'Dal Tadka',
    'lentil': 'Dal Tadka',
    'soup': 'Tomato Soup',
    'salad': 'Green Salad (no dressing)',
    'egg': 'Boiled Egg (1 pc)',
    'chicken': 'Chicken Curry',
    'fish': 'Fish Curry',
    'paneer': 'Palak Paneer',
    'vegetable': 'Mixed Vegetable Curry',
    'potato': 'Aloo Gobi',
    'idli': 'Idli (2 pcs)',
    'dosa': 'Dosa (1 plain)',
    'poha': 'Poha',
    'upma': 'Upma',
    'paratha': 'Paratha (Plain)',
    'samosa': 'Samosa (1 pc)',
    'biryani': 'Biryani (Veg)',
    'pulao': 'Pulao (Veg)',
    'khichdi': 'Khichdi',
    'yogurt': 'Curd / Yogurt (1 bowl)',
    'curd': 'Curd / Yogurt (1 bowl)',
    'milk': 'Milk (1 glass)',
    'banana': 'Banana (1 medium)',
    'apple': 'Apple (1 medium)',
    'mango': 'Mango (1 medium)',
    'orange': 'Orange (1 medium)',
    'grape': 'Grapes (100g)',
    'cake': 'Barfi (1 pc)',
    'pizza': 'Bread (White-1 slice)',
    'sandwich': 'Sandwich (Grilled)',
    'omelette': 'Omelette (2 eggs)',
    'meat': 'Chicken Curry',
    'fried rice': 'Fried Rice (Veg)',
    'noodle': 'Momos (Steamed-6 pcs)',
  };

  static Future<LocalAnalysisResult> analyze(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labels = await _labeler.processImage(inputImage);
    final labelTexts = labels.map((l) => l.label.toLowerCase()).toList();

    final candidates = <FoodItem>[];
    final matchedNames = <String>{};

    for (final label in labelTexts) {
      final alias = _foodAliases.entries.firstWhere(
        (e) => label.contains(e.key),
        orElse: () => MapEntry('', ''),
      );
      if (alias.value.isNotEmpty && !matchedNames.contains(alias.value)) {
        matchedNames.add(alias.value);
        final found = FoodDatabase.search(alias.value);
        if (found.isNotEmpty) candidates.add(found.first);
      }
    }

    for (final label in labelTexts) {
      final searchResults = FoodDatabase.search(label);
      for (final item in searchResults) {
        if (!matchedNames.contains(item.name)) {
          matchedNames.add(item.name);
          candidates.add(item);
        }
      }
    }

    final bestMatch = candidates.isNotEmpty ? candidates.first : null;
    return LocalAnalysisResult(
      bestMatch: bestMatch,
      labels: labels.map((l) => l.label).toList(),
      candidates: candidates.take(3).toList(),
    );
  }

  static void dispose() {
    _labeler.close();
  }
}
