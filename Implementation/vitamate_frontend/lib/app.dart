import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
import 'core/routing/app_navigator.dart';
import 'auth/screens/onboarding_wizard/onboarding_wizard_screen.dart';
import 'auth/screens/signup_screen.dart';
import 'core/routing/routes.dart';
import 'core/routing/vitamate_route_observer.dart';
import 'core/theme/vitamate_theme.dart';
import 'features/activity/screens/activity_screen.dart';
import 'features/chronic_conditions/screens/chronic_conditions_screen.dart';
import 'features/habits/screens/habits_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/manager/screens/account_security_screen.dart';
import 'features/manager/screens/data_privacy_screen.dart';
import 'features/manager/screens/edit_profile_screen.dart';
import 'features/manager/screens/goals_screen.dart';
import 'features/manager/screens/health_profile_screen.dart';
import 'features/manager/screens/medical_data_hub_screen.dart';
import 'features/manager/screens/my_vitamate_screen.dart';
import 'features/manager/screens/notifications_screen.dart';
import 'features/medications/screens/add_edit_medication_screen.dart';
import 'features/medications/screens/medication_history_screen.dart';
import 'features/medications/screens/medication_today_plan_screen.dart';
import 'features/medications/screens/medications_screen.dart';
import 'features/medications/state/medications_controller.dart';
import 'features/motivation/screens/motivation_experience_host.dart';
import 'features/nutrition/screens/nutrition_screen.dart';
import 'features/sleep/screens/sleep_screen.dart';
import 'features/stats/screens/stats_screen.dart';
import 'features/water/screens/water_screen.dart';

class VitaMateApp extends StatelessWidget {
  const VitaMateApp({
    super.key,
    this.initialRoute = Routes.login,
    this.routeOverrides = const <String, WidgetBuilder>{},
  });

  final String initialRoute;
  final Map<String, WidgetBuilder> routeOverrides;

  Map<String, WidgetBuilder> _defaultRoutes() {
    return <String, WidgetBuilder>{
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
      Routes.medsHistory: (_) => MedicationHistoryScreen(
        controller: MedicationsController()..refreshAll(),
      ),
      Routes.sleep: (_) => const SleepScreen(),
      Routes.water: (_) => const WaterScreen(),
      Routes.meals: (_) => const NutritionScreen(),
      Routes.activities: (_) => const ActivityScreen(),
      Routes.activityWorkouts: (_) => const ActivityScreen(),
      Routes.activitySteps: (_) => const ActivityScreen(),
      Routes.activityActiveTime: (_) => const ActivityScreen(),
      Routes.activitySessionSetup: (_) => const ActivityScreen(),
      Routes.activitySessionLive: (_) => const ActivityScreen(),
      Routes.activitySessionSummary: (_) => const ActivityScreen(),
      Routes.habits: (_) => const HabitsScreen(),
      Routes.steps: (_) => const ActivityScreen(),
      Routes.chronicConditions: (_) => const ChronicConditionsScreen(),
      Routes.goal: (_) => const ManagerGoalsScreen(),
      Routes.myVitaMate: (_) => const MyVitaMateScreen(),
      Routes.managerEditProfile: (_) => const EditProfileScreen(),
      Routes.managerHealthProfile: (_) => const HealthProfileScreen(),
      Routes.managerGoals: (_) => const ManagerGoalsScreen(),
      Routes.managerNotifications: (_) => const ManagerNotificationsScreen(),
      Routes.managerSecurity: (_) => const AccountSecurityScreen(),
      Routes.managerMedicalData: (_) => const MedicalDataHubScreen(),
      Routes.managerPrivacy: (_) => const DataPrivacyScreen(),
      Routes.score: (_) => const MyVitaMateScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final routes = <String, WidgetBuilder>{
      ..._defaultRoutes(),
      ...routeOverrides,
    };

    return MaterialApp(
      title: 'VitaMate',
      debugShowCheckedModeBanner: false,
      theme: VitaMateTheme.light(),
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      navigatorObservers: [vitaMateRouteObserver],
      initialRoute: initialRoute,
      routes: routes,
      builder: (context, child) =>
          MotivationExperienceHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
