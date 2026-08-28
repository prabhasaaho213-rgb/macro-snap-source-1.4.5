import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../models/diet_profile.dart';

/// Cal AI-style onboarding: collects user profile data before first use.
///
/// Flow: Welcome → Name → Gender → Age → Weight → Height → Goal → Activity → Done
/// Saves to [DietPlanService] so the home screen shows personalized targets.
class OnboardingScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingScreen({super.key, required this.nextScreen});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final ValueNotifier<int> _page = ValueNotifier(0);

  // User data
  String _name = '';
  Gender _gender = Gender.male;
  int _age = 25;
  double _weight = 70;
  double _height = 170;
  bool _isKg = true;
  bool _isCm = true;
  Goal _goal = Goal.loseWeight;
  ActivityLevel _activity = ActivityLevel.moderate;

  static const _totalSteps = 8;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_done', true);
    final name = _name.isNotEmpty ? _name : _nameController.text.trim();
    if (name.isNotEmpty) {
      await prefs.setString('name', name);
    }

    // Save diet profile
    final profile = DietProfile(
      weightKg: _isKg ? _weight : _weight * 0.453592,
      heightCm: _isCm ? _height : _height * 2.54,
      age: _age,
      gender: _gender,
      goal: _goal,
      activity: _activity,
    );
    DietPlanService.instance.save(profile);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    }
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_page.value < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _prev() {
    HapticFeedback.lightImpact();
    if (_page.value > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surfaceLight;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subText = MacroSnapTheme.textSecondary(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip + progress
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  if (_page.value > 0)
                    IconButton(
                      onPressed: _prev,
                      icon: Icon(Icons.arrow_back_rounded, color: textColor),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  ValueListenableBuilder<int>(
                    valueListenable: _page,
                    builder: (_, p, __) => Text(
                      '${p + 1}/$_totalSteps',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: subText,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _complete,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: subText, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            ValueListenableBuilder<int>(
              valueListenable: _page,
              builder: (_, p, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (p + 1) / _totalSteps,
                    backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation(MacroSnapTheme.neonGreen),
                    minHeight: 4,
                  ),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => _page.value = i,
                itemCount: _totalSteps,
                itemBuilder: (_, i) => _buildPage(i, textColor, subText, isDark),
              ),
            ),
            // Next / Done button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (_, p, __) => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: MacroSnapTheme.neonGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      p == _totalSteps - 1 ? 'GET STARTED' : 'NEXT',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int i, Color textColor, Color subText, bool isDark) {
    switch (i) {
      case 0: return _buildWelcome(textColor, subText);
      case 1: return _buildName(textColor, subText, isDark);
      case 2: return _buildGender(textColor, subText, isDark);
      case 3: return _buildAge(textColor, subText, isDark);
      case 4: return _buildWeight(textColor, subText, isDark);
      case 5: return _buildHeight(textColor, subText, isDark);
      case 6: return _buildGoal(textColor, subText, isDark);
      case 7: return _buildActivity(textColor, subText, isDark);
      return const SizedBox();
    }
  }

  // ── Page builders ──────────────────────────────────────────────

  Widget _buildWelcome(Color textColor, Color subText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: MacroSnapTheme.neonGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('📸', style: TextStyle(fontSize: 48))),
          ),
          const SizedBox(height: 28),
          Text(
            'Welcome to MacroSnap',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            "Let's set up your profile so we can give you personalized calorie and macro targets.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: subText, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildName(Color textColor, Color subText, bool isDark) {
    return _buildQuestion(
      'What is your name?',
      textColor,
      Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: MacroSnapTheme.neonGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('👋', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textColor),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: TextStyle(color: subText.withValues(alpha: 0.5)),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: MacroSnapTheme.neonGreen.withValues(alpha: 0.3)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: MacroSnapTheme.neonGreen, width: 2),
              ),
            ),
            onChanged: (v) => _name = v.trim(),
            onSubmitted: (_) => _next(),
          ),
        ],
      ),
    );
  }

  Widget _buildGender(Color textColor, Color subText, bool isDark) {
    return _buildQuestion(
      'What is your gender?',
      textColor,
      Row(
        children: [
          Expanded(child: _genderOption('👨', 'Male', Gender.male, isDark)),
          const SizedBox(width: 16),
          Expanded(child: _genderOption('👩', 'Female', Gender.female, isDark)),
        ],
      ),
    );
  }

  Widget _genderOption(String emoji, String label, Gender value, bool isDark) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: selected
              ? MacroSnapTheme.neonGreen.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1A1A22) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? MacroSnapTheme.neonGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildAge(Color textColor, Color subText, bool isDark) {
    return _buildQuestion(
      'How old are you?',
      textColor,
      Column(
        children: [
          Text('$_age', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: MacroSnapTheme.neonGreen)),
          const SizedBox(height: 4),
          Text('years', style: TextStyle(fontSize: 16, color: subText)),
          const SizedBox(height: 24),
          _numberAdjuster(
            value: _age,
            min: 14,
            max: 100,
            onMinus: () => setState(() => _age = (_age > 14 ? _age - 1 : 14)),
            onPlus: () => setState(() => _age = (_age < 100 ? _age + 1 : 100)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeight(Color textColor, Color subText, bool isDark) {
    final display = _isKg ? _weight : _weight / 0.453592;
    return _buildQuestion(
      'What is your weight?',
      textColor,
      Column(
        children: [
          // Unit toggle
          GestureDetector(
            onTap: () => setState(() => _isKg = !_isKg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isKg ? 'kg' : 'lbs',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MacroSnapTheme.neonGreen),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            display.toStringAsFixed(1),
            style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: MacroSnapTheme.neonGreen),
          ),
          const SizedBox(height: 4),
          Text(_isKg ? 'kilograms' : 'pounds', style: TextStyle(fontSize: 16, color: subText)),
          const SizedBox(height: 24),
          _numberAdjuster(
            value: display.round(),
            min: 30,
            max: 250,
            onMinus: () => setState(() => _weight = _isKg ? (_weight > 30 ? _weight - 0.5 : 30) : (_weight > 66 : _weight - 1.1 : 66)),
            onPlus: () => setState(() => _weight = _isKg ? (_weight < 250 ? _weight + 0.5 : 250) : (_weight < 551 ? _weight + 1.1 : 551)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeight(Color textColor, Color subText, bool isDark) {
    final display = _isCm ? _height : _height / 2.54;
    return _buildQuestion(
      'What is your height?',
      textColor,
      Column(
        children: [
          // Unit toggle
          GestureDetector(
            onTap: () => setState(() => _isCm = !_isCm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isCm ? 'cm' : 'in',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MacroSnapTheme.neonGreen),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            display.toStringAsFixed(1),
            style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: MacroSnapTheme.neonGreen),
          ),
          const SizedBox(height: 4),
          Text(_isCm ? 'centimeters' : 'inches', style: TextStyle(fontSize: 16, color: subText)),
          const SizedBox(height: 24),
          _numberAdjuster(
            value: display.round(),
            min: 100,
            max: 250,
            onMinus: () => setState(() => _height = _isCm ? (_height > 100 ? _height - 1 : 100) : (_height > 254 ? _height - 2.54 : 254)),
            onPlus: () => setState(() => _height = _isCm ? (_height < 250 ? _height + 1 : 250) : (_height < 635 ? _height + 2.54 : 635)),
          ),
        ],
      ),
    );
  }

  Widget _buildGoal(Color textColor, Color subText, bool isDark) {
    return _buildQuestion(
      'What is your goal?',
      textColor,
      Column(
        children: [
          _goalOption('🔥', 'Lose Weight', 'Calorie deficit for fat loss', Goal.loseWeight, isDark),
          const SizedBox(height: 12),
          _goalOption('⚖️', 'Maintain Weight', 'Stay at your current weight', Goal.maintain, isDark),
          const SizedBox(height: 12),
          _goalOption('💪', 'Gain Muscle', 'Calorie surplus for muscle gain', Goal.gainMuscle, isDark),
        ],
      ),
    );
  }

  Widget _goalOption(String emoji, String title, String subtitle, Goal value, bool isDark) {
    final selected = _goal == value;
    return GestureDetector(
      onTap: () => setState(() => _goal = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? MacroSnapTheme.neonGreen.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1A1A22) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? MacroSnapTheme.neonGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: MacroSnapTheme.textSecondary(context))),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: MacroSnapTheme.neonGreen, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActivity(Color textColor, Color subText, bool isDark) {
    final levels = [
      (ActivityLevel.sedentary, 'Sedentary', 'Desk job, little exercise'),
      (ActivityLevel.light, 'Light', '1-2 days/week exercise'),
      (ActivityLevel.moderate, 'Moderate', '3-5 days/week exercise'),
      (ActivityLevel.active, 'Active', '6-7 days/week exercise'),
      (ActivityLevel.veryActive, 'Very Active', 'Twice a day / physical job'),
    ];
    return _buildQuestion(
      'How active are you?',
      textColor,
      Column(
        children: levels.map((l) {
          final selected = _activity == l.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _activity = l.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? MacroSnapTheme.neonGreen.withValues(alpha: 0.12)
                      : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? MacroSnapTheme.neonGreen : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 2),
                          Text(l.$3, style: TextStyle(fontSize: 12, color: subText)),
                        ],
                      ),
                    ),
                    if (selected) Icon(Icons.check_circle_rounded, color: MacroSnapTheme.neonGreen, size: 22),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────

  Widget _buildQuestion(String title, Color textColor, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberAdjuster({
    required int value,
    required int min,
    required int max,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          icon: Icons.remove_rounded,
          onTap: value > min ? onMinus : null,
        ),
        const SizedBox(width: 32),
        Text(
          '$value',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 32),
        _circleButton(
          icon: Icons.add_rounded,
          onTap: value < max ? onPlus : null,
        ),
      ],
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onTap != null
              ? MacroSnapTheme.neonGreen.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap != null ? MacroSnapTheme.neonGreen : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
