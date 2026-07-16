import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../models/diet_profile.dart';
import '../services/meal_store.dart';
import '../widgets/glass_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/gradient_button.dart';
import 'subscription_screen.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _serverUrl = 'https://macro-snap-backend-production.up.railway.app';
  Gender _gender = Gender.male;
  Goal _goal = Goal.loseWeight;
  ActivityLevel _activity = ActivityLevel.sedentary;
  DietProfile? _profile;
  String _avatar = 'ðŸ˜Ž';
  bool _subscribed = false;
  bool _generating = false;
  Map<String, dynamic>? _aiPlan;
  String _aiError = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await DietPlanService.instance.load();
    final p = DietPlanService.instance.profile;
    final prefs = await SharedPreferences.getInstance();
    final subscribed = prefs.getBool('subscribed') ?? false;
    if (mounted) {
      setState(() => _subscribed = subscribed);
      if (p != null) {
        setState(() {
          _profile = p;
          _avatar = p.avatar;
          _weightCtrl.text = p.weightKg.toStringAsFixed(1);
          _heightCtrl.text = p.heightCm.toStringAsFixed(1);
          _ageCtrl.text = p.age.toString();
          _gender = p.gender;
          _goal = p.goal;
          _activity = p.activity;
        });
      }
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _showAvatarPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Choose Your Avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12, runSpacing: 12,
              alignment: WrapAlignment.center,
              children: DietProfile.avatars.map((a) => GestureDetector(
                onTap: () {
                  setState(() { _avatar = a; });
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _avatar == a ? MacroSnapTheme.emerald.withOpacity( 0.15) : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                    border: _avatar == a ? Border.all(color: MacroSnapTheme.emerald, width: 2) : null,
                  ),
                  child: Center(child: Text(a, style: const TextStyle(fontSize: 28))),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _calculate() {
    final w = double.tryParse(_weightCtrl.text);
    final h = double.tryParse(_heightCtrl.text);
    final a = int.tryParse(_ageCtrl.text);
    if (w == null || h == null || a == null || w <= 0 || h <= 0 || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Enter valid weight, height & age'), backgroundColor: MacroSnapTheme.rose),
      );
      return;
    }
    final profile = DietProfile(weightKg: w, heightCm: h, age: a, gender: _gender, goal: _goal, activity: _activity, avatar: _avatar);
    DietPlanService.instance.save(profile);
    setState(() => _profile = profile);
  }

  Future<void> _generateAiPlan() async {
    if (_profile == null) return;
    if (!_subscribed) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
      return;
    }
    setState(() { _generating = true; _aiError = ''; _aiPlan = null; });
    try {
      final resp = await http.post(
        Uri.parse('$_serverUrl/generate-diet-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'weight': _profile!.weightKg,
          'height': _profile!.heightCm,
          'age': _profile!.age,
          'gender': _profile!.gender.name,
          'goal': _profile!.goal.name,
          'activity': _profile!.activity.name,
        }),
      );
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) throw Exception(data['error'] ?? 'Failed to generate');
      if (mounted) setState(() { _aiPlan = data; _generating = false; });
    } catch (e) {
      if (mounted) setState(() { _aiError = e.toString().replaceFirst('Exception: ', ''); _generating = false; });
    }
  }

  void _reset() {
    DietPlanService.instance.save(DietProfile(weightKg: 70, heightCm: 170, age: 25, gender: Gender.male, goal: Goal.maintain, activity: ActivityLevel.moderate));
    _weightCtrl.text = '70';
    _heightCtrl.text = '170';
    _ageCtrl.text = '25';
    setState(() { _gender = Gender.male; _goal = Goal.maintain; _activity = ActivityLevel.moderate; _profile = null; _avatar = 'ðŸ˜Ž'; _aiPlan = null; _aiError = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Diet Plan'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _reset)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInputSection(isDark),
            if (_profile != null) ...[
              const SizedBox(height: 20),
              _buildTargetsCard(isDark),
              const SizedBox(height: 16),
              _buildAiSection(isDark),
              const SizedBox(height: 16),
              _buildProgressCard(isDark),
              const SizedBox(height: 16),
              _buildMealPlan(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: () => _showAvatarPicker(isDark),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: MacroSnapTheme.emerald.withOpacity( 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(_avatar, style: const TextStyle(fontSize: 36))),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Tap to change avatar', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
          ),
          const SizedBox(height: 16),
          Text('Your Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _weightCtrl, label: 'Weight (kg)', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: _heightCtrl, label: 'Height (cm)', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: _ageCtrl, label: 'Age', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Gender>(
            value: _gender,
            decoration: InputDecoration(labelText: 'Gender', filled: true, fillColor: isDark ? const Color(0xFF1E293B) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
            items: const [DropdownMenuItem(value: Gender.male, child: Text('Male')), DropdownMenuItem(value: Gender.female, child: Text('Female'))],
            onChanged: (v) => setState(() => _gender = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Goal>(
            value: _goal,
            decoration: InputDecoration(labelText: 'Goal', filled: true, fillColor: isDark ? const Color(0xFF1E293B) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
            items: Goal.values.map((g) => DropdownMenuItem(value: g, child: Text(DietPlanService.goalLabel(g)))).toList(),
            onChanged: (v) => setState(() => _goal = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ActivityLevel>(
            value: _activity,
            decoration: InputDecoration(labelText: 'Activity Level', filled: true, fillColor: isDark ? const Color(0xFF1E293B) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
            items: ActivityLevel.values.map((a) => DropdownMenuItem(value: a, child: Text(DietPlanService.activityLabel(a)))).toList(),
            onChanged: (v) => setState(() => _activity = v!),
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Calculate & Save', onPressed: _calculate, height: 52),
        ],
      ),
    );
  }

  Widget _buildTargetsCard(bool isDark) {
    final p = _profile!;
    final bmi = p.weightKg / ((p.heightCm / 100) * (p.heightCm / 100));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: MacroSnapTheme.emerald.withOpacity( 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(DietPlanService.goalLabel(p.goal), style: const TextStyle(color: MacroSnapTheme.emerald, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('${p.targetCalories} kcal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 8),
          Text('BMI ${bmi.toStringAsFixed(1)} | BMR ${p.bmr.round()} kcal | TDEE ${p.tdee.round()} kcal',
              overflow: TextOverflow.ellipsis, maxLines: 1,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _targetItem('Protein', p.targetProtein.toInt(), 'g', MacroSnapTheme.rose, isDark),
              _targetItem('Carbs', p.targetCarbs.toInt(), 'g', MacroSnapTheme.amber, isDark),
              _targetItem('Fats', p.targetFats.toInt(), 'g', MacroSnapTheme.blue, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetItem(String label, int value, String unit, Color color, bool isDark) {
    return Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity( 0.1)),
        child: Center(child: Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
      ),
      const SizedBox(height: 4),
      Text('$label ($unit)', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
    ]);
  }

  Widget _buildAiSection(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Text('Personalized Meal Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 16),
          if (_aiPlan != null) ...[
            _buildAiMeals(isDark),
            if (_aiPlan!['plan'] is Map && (_aiPlan!['plan'] as Map)['tips'] != null) ...[
              const SizedBox(height: 12),
              ...((_aiPlan!['plan'] as Map)['tips'] as List).map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ðŸ’¡ ', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
                  Expanded(child: Text('$tip', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8)))),
                ]),
              )),
            ],
            if (_aiPlan!['plan'] is Map && (_aiPlan!['plan'] as Map)['water'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.water_drop, size: 16, color: MacroSnapTheme.blue),
                const SizedBox(width: 6),
                Text('${_aiPlan!['plan']['water']}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
              ]),
            ],
          ] else ...[
            if (_aiError.isNotEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? MacroSnapTheme.rose.withOpacity( 0.15) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_aiError, style: TextStyle(color: isDark ? MacroSnapTheme.rose : const Color(0xFFDC2626), fontSize: 12)),
              ),
            GradientButton(
              label: _generating ? 'Generating...' : _subscribed ? 'Generate AI Meal Plan' : 'Subscribe to Unlock AI Plan',
              icon: _generating ? null : _subscribed ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
              onPressed: _generating ? null : _generateAiPlan,
              loading: _generating,
              height: 48,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiMeals(bool isDark) {
    if (_aiPlan!['plan'] is! Map) return const SizedBox.shrink();
    final meals = (_aiPlan!['plan'] as Map)['meals'] as List? ?? [];
    if (meals.isEmpty) return const SizedBox.shrink();
    return Column(children: meals.map((m) {
      final meal = m as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(meal['time'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MacroSnapTheme.emerald)),
              const Spacer(),
              Text('${meal['calories'] ?? 0} kcal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            ]),
            const SizedBox(height: 4),
            Text(meal['name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(meal['description'] ?? '', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
            const SizedBox(height: 4),
            Row(children: [
              _macroChip('P ${meal['protein_g'] ?? 0}g', MacroSnapTheme.rose),
              const SizedBox(width: 6),
              _macroChip('C ${meal['carbs_g'] ?? 0}g', MacroSnapTheme.amber),
              const SizedBox(width: 6),
              _macroChip('F ${meal['fats_g'] ?? 0}g', MacroSnapTheme.blue),
            ]),
          ]),
        ),
      );
    }).toList());
  }

  Widget _macroChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity( 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    final p = _profile!;
    final cal = MealStore.instance.todayCalories;
    final protein = MealStore.instance.todayProtein;
    final ratio = (cal / p.targetCalories).clamp(0.0, 1.0);
    final protRatio = (protein / p.targetProtein).clamp(0.0, 1.0);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Progress", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _progressRow('Calories', cal, p.targetCalories, ratio, MacroSnapTheme.amber, isDark),
          const SizedBox(height: 12),
          _progressRow('Protein', protein.toInt(), p.targetProtein.toInt(), protRatio, MacroSnapTheme.rose, isDark),
        ],
      ),
    );
  }

  Widget _progressRow(String label, int current, int target, double ratio, Color color, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
        Text('$current / $target', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
      ]),
      const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
    ]);
  }

  Widget _buildMealPlan(bool isDark) {
    final p = _profile!;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggested Meal Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _mealItem(Icons.wb_sunny_rounded, 'Breakfast (~${(p.targetCalories * 0.25).round()} kcal)', _breakfastSuggestion(p), MacroSnapTheme.amber, isDark),
          _mealItem(Icons.free_breakfast_rounded, 'Morning Snack (~${(p.targetCalories * 0.1).round()} kcal)', _snackSuggestion(p), MacroSnapTheme.emerald, isDark),
          _mealItem(Icons.wb_cloudy_rounded, 'Lunch (~${(p.targetCalories * 0.3).round()} kcal)', _lunchSuggestion(p), MacroSnapTheme.blue, isDark),
          _mealItem(Icons.nightlight_round, 'Evening Snack (~${(p.targetCalories * 0.1).round()} kcal)', _snackSuggestion(p), MacroSnapTheme.emerald, isDark),
          _mealItem(Icons.nights_stay_rounded, 'Dinner (~${(p.targetCalories * 0.25).round()} kcal)', _dinnerSuggestion(p), MacroSnapTheme.rose, isDark),
          const SizedBox(height: 16),
          Text('Portion sizes are approximate. Adjust based on your appetite and progress.', style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _mealItem(IconData icon, String title, String suggestion, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity( 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(suggestion, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
        ])),
      ]),
    );
  }

  String _breakfastSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return '2 egg whites + 1 multigrain roti + 1 bowl curd + mixed veggies';
    return '2 whole eggs + 2 multigrain roti + 1 bowl sprouts salad + 1 banana';
  }

  String _lunchSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return '1 roti + dal + green veg sabzi + salad + buttermilk';
    if (p.goal == Goal.gainMuscle) return '2 roti + dal + paneer bhurji + rice + curd + salad';
    return '2 roti + dal + seasonal veg + salad + curd';
  }

  String _dinnerSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return 'Grilled chicken/fish + stir-fried veggies + soup';
    if (p.goal == Goal.gainMuscle) return 'Chicken/paneer + rice + veggies + 1 glass milk';
    return 'Light roti/kichdi + veg curry + salad';
  }

  String _snackSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return '1 apple + 5 almonds or green tea / black coffee';
    if (p.goal == Goal.gainMuscle) return 'Handful dry fruits + 1 glass milk + 1 banana';
    return '1 fruit + buttermilk or handful of roasted chana';
  }
}

