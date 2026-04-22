class AppRuntime {
  AppRuntime._();

  static bool notificationsEnabled = true;

  static void configure({required bool enableNotifications}) {
    notificationsEnabled = enableNotifications;
  }
}
