import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../data/manager_repository.dart';
import '../models/manager_models.dart';

class AccountSecurityController extends ChangeNotifier {
  AccountSecurityController({ManagerRepository? repository})
    : _repository = repository ?? ManagerRepository();

  final ManagerRepository _repository;

  bool isLoading = false;
  bool isSaving = false;
  String? error;
  ManagerSecurity? security;

  Future<void> load() async {
    isLoading = security == null;
    error = null;
    notifyListeners();
    try {
      security = await _repository.getSecurity();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load security settings.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> logoutAll() async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.logoutAll();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to log out devices.',
      );
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirm: newPasswordConfirm,
      );
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to change password.',
      );
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
