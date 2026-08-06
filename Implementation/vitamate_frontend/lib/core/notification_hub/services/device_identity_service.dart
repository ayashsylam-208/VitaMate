import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentityService {
  static const String _installationIdKey = 'notification_hub.installation_id';

  static Future<String> installationId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installationIdKey)?.trim() ?? '';
    if (existing.isNotEmpty) {
      return existing;
    }
    final value =
        'vm-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
    await prefs.setString(_installationIdKey, value);
    return value;
  }
}
