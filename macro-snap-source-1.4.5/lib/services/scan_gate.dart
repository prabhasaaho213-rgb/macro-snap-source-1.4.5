import 'package:shared_preferences/shared_preferences.dart';

class ScanGate {
  static const int _freeLimit = 3;
  static const String _key = 'scan_count';
  static const String _monthKey = 'scan_month';

  static Future<int> getScansUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewMonth(prefs);
    return prefs.getInt(_key) ?? 0;
  }

  static Future<int> getScansRemaining() async {
    final used = await getScansUsed();
    final sub = await _isSubscribed();
    if (sub) return 999;
    return (_freeLimit - used).clamp(0, _freeLimit);
  }

  static Future<bool> canScan() async {
    final sub = await _isSubscribed();
    if (sub) return true;
    final used = await getScansUsed();
    return used < _freeLimit;
  }

  static Future<int> incrementScan() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewMonth(prefs);
    final count = (prefs.getInt(_key) ?? 0) + 1;
    await prefs.setInt(_key, count);
    return count;
  }

  static Future<bool> _isSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('subscribed') ?? false;
  }

  static Future<void> _resetIfNewMonth(SharedPreferences prefs) async {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final savedMonth = prefs.getString(_monthKey) ?? '';
    if (savedMonth != currentMonth) {
      await prefs.setInt(_key, 0);
      await prefs.setString(_monthKey, currentMonth);
    }
  }
}
