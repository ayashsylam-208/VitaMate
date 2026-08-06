import 'package:flutter/foundation.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/user.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/sync/health_sync_bus.dart';

class HealthProfileController extends ChangeNotifier {
  HealthProfileController({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(AuthApi());

  final AuthRepository _repository;

  bool isLoading = false;
  bool isSaving = false;
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
        fallback: 'Failed to load health profile.',
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
      HealthSyncBus.instance.notifyTrackerDataChanged();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Health profile update failed.',
      );
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
