import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
import 'auth/screens/onboarding_wizard/onboarding_wizard_screen.dart';
import 'auth/screens/signup_screen.dart';
import 'core/routing/routes.dart';
import 'core/theme/vitamate_theme.dart';
import 'features/activity/screens/activity_screen.dart';
import 'features/chronic_conditions/screens/chronic_conditions_screen.dart';
import 'features/goals/screens/goals_screen.dart';
import 'features/habits/screens/habits_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/medications/screens/add_edit_medication_screen.dart';
import 'features/medications/screens/medication_today_plan_screen.dart';
import 'features/medications/screens/medications_screen.dart';
import 'features/medications/state/medications_controller.dart';
import 'features/nutrition/screens/nutrition_screen.dart';
import 'features/sleep/screens/sleep_screen.dart';
import 'features/stats/screens/stats_screen.dart';
import 'features/steps/screens/steps_screen.dart';
import 'features/water/screens/water_screen.dart';
import 'shared/widgets/vitamate_bottom_nav.dart';

class VitaMateApp extends StatelessWidget {
  const VitaMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitaMate',
      debugShowCheckedModeBanner: false,
      theme: VitaMateTheme.light(),
      initialRoute: Routes.login,
      routes: {
        Routes.login: (_) => const LoginScreen(),
        Routes.signup: (_) => const SignUpScreen(),
        Routes.onboarding: (_) => const OnboardingWizardScreen(),
        Routes.home: (_) => const HomeScreen(),
        Routes.progress: (_) => const StatsScreen(),
        Routes.meds: (_) => const MedicationsScreen(),
        Routes.medsAdd: (_) =>
            AddEditMedicationScreen(controller: MedicationsController()),
        Routes.medsToday: (_) => MedicationTodayPlanScreen(
          controller: MedicationsController()..refreshAll(),
        ),
        Routes.sleep: (_) => const SleepScreen(),
        Routes.water: (_) => const WaterScreen(
          targetValueFromBackend: 2.3,
          targetIsLiters: true,
        ),
        Routes.meals: (_) => const NutritionScreen(),
        Routes.activities: (_) => const ActivityScreen(),
        Routes.habits: (_) => const HabitsScreen(),
        Routes.steps: (_) => const StepsScreen(),
        Routes.chronicConditions: (_) => const ChronicConditionsScreen(),
        Routes.goal: (_) => const GoalsScreen(),
        Routes.score: (_) => const _ScoreSummaryScreen(),
      },
    );
  }
}

class _ScoreSummaryScreen extends StatelessWidget {
  const _ScoreSummaryScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 4),
      appBar: AppBar(title: const Text('Score Summary')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Score insights are not wired yet.',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'This route stays available so the home flow remains complete while the detailed score module is implemented.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
