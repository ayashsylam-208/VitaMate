import 'package:flutter/material.dart';
import 'core/routing/routes.dart';
import 'core/theme/vitamate_theme.dart';

// auth
import 'auth/screens/login_screen.dart';
import 'auth/screens/signup_screen.dart';
import 'auth/screens/onboarding_wizard/onboarding_wizard_screen.dart';

// home
import 'features/home/screens/home_screen.dart';

// features
import 'features/stats/screens/stats_screen.dart';
import 'features/sleep/screens/sleep_screen.dart';
import 'features/water/screens/water_screen.dart';
import 'features/nutrition/screens/nutrition_screen.dart';
import 'features/activity/screens/activity_screen.dart';
import 'features/goals/screens/goals_screen.dart';

class VitaMateApp extends StatelessWidget {
  const VitaMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitaMate',
      debugShowCheckedModeBanner: false,
      theme: VitaMateTheme.light(),

      // Start at Login
      initialRoute: Routes.login,

      routes: {
        // Auth
        Routes.login: (_) => const LoginScreen(),
        Routes.signup: (_) => const SignUpScreen(),
        Routes.onboarding: (_) => const OnboardingWizardScreen(),

        // Home
        Routes.home: (_) => const HomeScreen(),

        // Features
        Routes.progress: (_) => const StatsScreen(),
        Routes.sleep: (_) => const SleepScreen(), // ✅ FIXED NAME
        Routes.water: (_) => const WaterScreen(
          targetValueFromBackend: 2.3, // liters (example)
          targetIsLiters: true,
        ),

        Routes.meals: (_) => const NutritionScreen(),
        Routes.activities: (_) => const ActivityScreen(),
        Routes.goal: (_) => const GoalsScreen(),

        // ✅ Missing route used by Home (Details button)
        Routes.score: (_) => const _ScorePlaceholderScreen(),
      },
    );
  }
}

/// Temporary screen until you implement the real Score screen
class _ScorePlaceholderScreen extends StatelessWidget {
  const _ScorePlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'Score details (Coming soon)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
