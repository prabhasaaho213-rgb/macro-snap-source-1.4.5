import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/food_database.dart';
import '../widgets/glass_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<FoodItem> _results = [];
  bool _showResults = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _showResults = query.isNotEmpty;
      _results = FoodDatabase.search(query);
    });
  }

  void _selectFood(FoodItem item) {
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Search Food'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search dal, roti, biryani...',
                  hintStyle: TextStyle(
                    color: MacroSnapTheme.textQuaternary(context),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: MacroSnapTheme.neonGreen),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? MacroSnapTheme.cardDark : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: MacroSnapTheme.borderSubtle(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: MacroSnapTheme.neonGreen, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  fontSize: 15,
                ),
              ),
            ),
            if (!_showResults) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MacroSnapTheme.textSecondary(context),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: FoodDatabase.categories.map((cat) => _buildCategoryCard(cat, isDark)).toList(),
                ),
              ),
            ] else ...[
              if (_results.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: MacroSnapTheme.borderSubtle(context)),
                        const SizedBox(height: 12),
                        Text(
                          'No foods found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: MacroSnapTheme.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _buildFoodItem(_results[i], isDark),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _results = FoodDatabase.getByCategory(category);
          _showResults = true;
        });
      },
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MacroSnapTheme.neonGreen.withValues(alpha:  0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  category[0],
                  style: const TextStyle(
                    color: MacroSnapTheme.neonGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              category,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem(FoodItem item, bool isDark) {
    return GestureDetector(
      onTap: () => _selectFood(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? MacroSnapTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MacroSnapTheme.borderSubtle(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.serving} Â· ${item.category}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: MacroSnapTheme.textTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.calories}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'kcal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: MacroSnapTheme.textTertiary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: MacroSnapTheme.textQuaternary(context)),
          ],
        ),
      ),
    );
  }
}

