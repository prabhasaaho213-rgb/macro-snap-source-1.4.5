import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../services/barcode_db.dart';
import '../services/meal_store.dart';
import '../widgets/celebration.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  BarcodeFood? _found;
  bool _scanning = true;

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    final food = BarcodeDb.lookup(barcode);
    if (food != null && mounted) {
      setState(() {
        _found = food;
        _scanning = false;
      });
    } else if (mounted) {
      // Barcode not in DB — show manual entry
      setState(() {
        _found = null;
        _scanning = false;
      });
      _showManualEntry(barcode);
    }
  }

  Future<void> _log() async {
    if (_found == null) return;
    MealStore.instance.add(
      MealRecord(
        id: 'barcode_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        name: _found!.name,
        category: _found!.brand,
        calories: (_found!.caloriesPer100g).round(),
        protein: _found!.proteinPer100g,
        carbs: _found!.carbsPer100g,
        fats: _found!.fatsPer100g,
        fiber: _found!.fiberPer100g,
        serving: '100g',
      ),
    );
    if (mounted) {
      await showCelebration(context, message: 'Logged!');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showManualEntry(String barcode) async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? MacroSnapTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Product Not Found'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Barcode not in our database. Enter nutrition manually:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Food name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: calCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calories (per 100g)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: proCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: carbCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fatCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fats (g)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _scanning = true);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final food = BarcodeFood(
                  barcode: barcode,
                  name: nameCtrl.text.trim(),
                  brand: 'Manual Entry',
                  caloriesPer100g: int.tryParse(calCtrl.text) ?? 0,
                  proteinPer100g: double.tryParse(proCtrl.text) ?? 0,
                  carbsPer100g: double.tryParse(carbCtrl.text) ?? 0,
                  fatsPer100g: double.tryParse(fatCtrl.text) ?? 0,
                );
                setState(() => _found = food);
                Navigator.pop(ctx);
              },
              child: const Text('Log It'),
            ),
          ],
        );
      },
    );
    nameCtrl.dispose();
    calCtrl.dispose();
    proCtrl.dispose();
    carbCtrl.dispose();
    fatCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan Barcode',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: _found != null ? _buildResult(isDark) : _buildScanner(isDark),
    );
  }

  Widget _buildScanner(bool isDark) {
    return Stack(
      children: [
        MobileScanner(onDetect: _onDetect),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: MacroSnapTheme.neonGreen, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 80,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text(
            'Point camera at barcode',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(bool isDark) {
    final f = _found!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.neonGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: MacroSnapTheme.neonGreen,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  f.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  f.brand,
                  style: TextStyle(
                    fontSize: 14,
                    color: MacroSnapTheme.textTertiary(context),
                  ),
                ),
                const Divider(height: 32),
                _row(
                  'Calories',
                  '${f.caloriesPer100g} kcal',
                  MacroSnapTheme.macroCalories,
                  isDark,
                ),
                _row(
                  'Protein',
                  '${f.proteinPer100g.toStringAsFixed(1)}g',
                  MacroSnapTheme.macroProtein,
                  isDark,
                ),
                _row(
                  'Carbs',
                  '${f.carbsPer100g.toStringAsFixed(1)}g',
                  MacroSnapTheme.macroCalories,
                  isDark,
                ),
                _row(
                  'Fats',
                  '${f.fatsPer100g.toStringAsFixed(1)}g',
                  MacroSnapTheme.macroFats,
                  isDark,
                ),
                if (f.fiberPer100g > 0)
                  _row(
                    'Fiber',
                    '${f.fiberPer100g.toStringAsFixed(1)}g',
                    MacroSnapTheme.greenText(context),
                    isDark,
                  ),
                if (f.sugarPer100g > 0)
                  _row(
                    'Sugar',
                    '${f.sugarPer100g.toStringAsFixed(1)}g',
                    const Color(0xFFDB2777),
                    isDark,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GradientButton(label: 'Log It', onPressed: _log),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() {
                    _found = null;
                    _scanning = true;
                  }),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? MacroSnapTheme.cardDark
                        : const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Scan Again',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: MacroSnapTheme.textPrimaryMuted(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: MacroSnapTheme.textPrimaryMuted(context),
            ),
          ),
          const Spacer(),
          Text(
            value,
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
