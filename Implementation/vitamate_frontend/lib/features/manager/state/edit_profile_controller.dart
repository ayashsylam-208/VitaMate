import 'package:flutter/foundation.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/user.dart';
import '../../../core/network/network_error_mapper.dart';
import '../data/manager_repository.dart';

class EditProfileController extends ChangeNotifier {
  EditProfileController({
    AuthRepository? repository,
    ManagerRepository? managerRepository,
  }) : _repository = repository ?? AuthRepository(AuthApi()),
       _managerRepository = managerRepository ?? ManagerRepository();

  final AuthRepository _repository;
  final ManagerRepository _managerRepository;

  bool isLoading = false;
  bool isSaving = false;
  bool isAvatarSaving = false;
  String? error;
  AuthUser? user;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repository.getMe();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load profile.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save(Map<String, dynamic> payload) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      user = await _repository.updateMe(payload);
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Profile update failed.',
      );
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    isAvatarSaving = true;
    error = null;
    notifyListeners();
    try {
      user = await _managerRepository.uploadAvatar(filePath);
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Avatar upload failed.',
      );
      return false;
    } finally {
      isAvatarSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAvatar() async {
    isAvatarSaving = true;
    error = null;
    notifyListeners();
    try {
      await _managerRepository.deleteAvatar();
      user = await _repository.getMe();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Avatar removal failed.',
      );
      return false;
    } finally {
      isAvatarSaving = false;
      notifyListeners();
    }
  }
}
