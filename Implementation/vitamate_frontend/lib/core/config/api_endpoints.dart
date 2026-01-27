class ApiEndpoints {
  // Backend base URL (update when network changes).
  static const String baseUrl = 'http://192.168.1.103:8000';

  // ✅ Auth (SimpleJWT)
  static const String register = '/api/auth/register/';
  static const String login = '/api/auth/login/';
  static const String refresh = '/api/auth/refresh/';
  static const String me = '/api/auth/me/';

  // ✅ Dashboard
  static const String dashboard = '/api/dashboard/';
  static const String history = '/api/history/';

  // ✅ Router endpoints (حسب router.register في Django)
  static const String meals = '/api/meals/';
  static const String water = '/api/water/';
  static const String medicines = '/api/medicines/';
  static const String steps = '/api/steps/';
  static const String activities = '/api/activities/';
  static const String exercises = '/api/exercises/';
  static const String sleep = '/api/sleep/';
  static const String habits = '/api/habits/';
  static const String foods = '/api/foods/';
}
