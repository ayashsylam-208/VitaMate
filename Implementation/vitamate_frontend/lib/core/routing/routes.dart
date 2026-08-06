class Routes {
  // Auth
  static const String login = '/login';
  static const String signup = '/signup';
  static const String onboarding = '/onboarding';

  // Home
  static const String home = '/home';

  // Features
  static const String progress = '/progress'; // Stats screen
  static const String goal = '/goal'; // Goals screen

  static const String steps = '/steps';
  static const String water = '/water';
  static const String meals = '/meals';
  static const String meds = '/medications';
  static const String medsAdd = '/medications/add';
  static const String medsToday = '/medications/today';
  static const String medsHistory = '/medications/history';
  static const String activities = '/activities';
  static const String activityWorkouts = '/activities/workouts';
  static const String activitySteps = '/activities/steps';
  static const String activityActiveTime = '/activities/active-time';
  static const String activitySessionSetup = '/activities/workouts/setup';
  static const String activitySessionLive = '/activities/sessions/live';
  static const String activitySessionSummary = '/activities/sessions/summary';
  static const String habits = '/habits';
  static const String sleep = '/sleep';
  static const String chronicConditions = '/chronic-conditions';

  // Optional
  static const String score = '/score';
  static const String myVitaMate = '/my-vitamate';
  static const String managerEditProfile = '/my-vitamate/edit-profile';
  static const String managerHealthProfile = '/my-vitamate/health-profile';
  static const String managerGoals = '/my-vitamate/goals';
  static const String managerNotifications = '/my-vitamate/notifications';
  static const String managerSecurity = '/my-vitamate/security';
  static const String managerMedicalData = '/my-vitamate/medical-data';
  static const String managerPrivacy = '/my-vitamate/privacy';
}
