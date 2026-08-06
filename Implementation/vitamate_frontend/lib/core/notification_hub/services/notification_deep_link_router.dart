import '../../routing/app_navigator.dart';

class NotificationDeepLinkRouter {
  static Future<void> open(String route) {
    return pushAppRoute(route);
  }
}
