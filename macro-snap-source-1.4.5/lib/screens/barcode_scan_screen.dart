import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../services/barcode_db.dart';
import '../services/meal_store.dart';
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
    if (!_scanning || _found != null) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    final food = BarcodeDb.lookup(barcode);
    if (food != null && mounted) {
      setState(() { _found = food; _scanning = false; });
    }
  }

  void _log() {
    if (_found == null) return;
    MealStore.instance.add(MealRecord(
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
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged!'), behavior: SnackBarBehavior.floating),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Barcode',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B))),
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
              border: Border.all(color: MacroSnapTheme.emerald, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(Icons.qr_code_scanner_rounded,
                  size: 80, color: Colors.white.withOpacity( 0.3)),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text('Point camera at barcode',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70, fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(blurRadius: 10, color: Colors.black.withOpacity( 0.5))],
              )),
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
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.emerald.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: MacroSnapTheme.emerald, size: 36),
                ),
                const SizedBox(height: 16),
                Text(f.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(f.brand, style: TextStyle(fontSize: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                const Divider(height: 32),
                _row('Calories', '${f.caloriesPer100g} kcal', MacroSnapTheme.amber, isDark),
                _row('Protein', '${f.proteinPer100g.toStringAsFixed(1)}g', MacroSnapTheme.rose, isDark),
                _row('Carbs', '${f.carbsPer100g.toStringAsFixed(1)}g', MacroSnapTheme.amber, isDark),
                _row('Fats', '${f.fatsPer100g.toStringAsFixed(1)}g', MacroSnapTheme.blue, isDark),
                if (f.fiberPer100g > 0) _row('Fiber', '${f.fiberPer100g.toStringAsFixed(1)}g', MacroSnapTheme.emerald, isDark),
                if (f.sugarPer100g > 0) _row('Sugar', '${f.sugarPer100g.toStringAsFixed(1)}g', const Color(0xFFDB2777), isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'Log It',
                  onPressed: _log,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() { _found = null; _scanning = true; }),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? MacroSnapTheme.cardDark : const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Scan Again',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569))),
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
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF475569))),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
