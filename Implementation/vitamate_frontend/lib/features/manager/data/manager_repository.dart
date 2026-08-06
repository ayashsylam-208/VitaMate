import '../../../auth/models/user.dart';
import '../models/manager_models.dart';
import 'manager_api.dart';

class ManagerRepository {
  ManagerRepository({ManagerApi? api}) : _api = api ?? ManagerApi();

  final ManagerApi _api;

  Future<ManagerOverview> getOverview() async {
    return ManagerOverview.fromJson(await _api.overview());
  }

  Future<List<ManagerGoal>> getGoals() async {
    final raw = await _api.goals();
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    final list = data['goals'] is List ? data['goals'] as List : const [];
    return list
        .whereType<Map>()
        .map((item) => ManagerGoal.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<ManagerGoal> updateGoal(String key, double? customValue) async {
    final raw = await _api.updateGoal(key, <String, dynamic>{
      'custom_value': customValue,
    });
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    final goal = data['goal'] is Map ? data['goal'] as Map : const {};
    return ManagerGoal.fromJson(goal.cast<String, dynamic>());
  }

  Future<List<ManagerGoal>> resetGoals() async {
    final raw = await _api.resetGoals();
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    final list = data['goals'] is List ? data['goals'] as List : const [];
    return list
        .whereType<Map>()
        .map((item) => ManagerGoal.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getNotifications() => _api.notifications();

  Future<Map<String, dynamic>> updateNotifications(
    Map<String, dynamic> payload,
  ) {
    return _api.updateNotifications(payload);
  }

  Future<ManagerSecurity> getSecurity() async {
    return ManagerSecurity.fromJson(await _api.security());
  }

  Future<AuthUser> uploadAvatar(String filePath) async {
    final raw = await _api.uploadAvatar(filePath);
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    final user = data['user'] is Map ? data['user'] as Map : const {};
    return AuthUser.fromJson(user.cast<String, dynamic>());
  }

  Future<void> deleteAvatar() async {
    await _api.deleteAvatar();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    await _api.changePassword(<String, dynamic>{
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirm': newPasswordConfirm,
    });
  }

  Future<void> logoutAll() async {
    await _api.logoutAll();
  }

  Future<ManagerPrivacySummary> getPrivacy() async {
    final raw = await _api.privacy();
    final data = raw['data'] is Map ? raw['data'] as Map : raw;
    return ManagerPrivacySummary.fromJson(data.cast<String, dynamic>());
  }

  Future<ManagerPrivacySummary> requestExport() async {
    await _api.requestExport();
    return getPrivacy();
  }

  Future<ManagerPrivacySummary> requestAccountDeletion({
    String reason = '',
  }) async {
    await _api.requestAccountDeletion(reason: reason);
    return getPrivacy();
  }

  Future<ManagerPrivacySummary> cancelAccountDeletion() async {
    await _api.cancelAccountDeletion();
    return getPrivacy();
  }
}
