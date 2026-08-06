import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../data/manager_repository.dart';
import '../models/manager_models.dart';

class PrivacyController extends ChangeNotifier {
  PrivacyController({ManagerRepository? repository})
    : _repository = repository ?? ManagerRepository();

  final ManagerRepository _repository;

  bool isLoading = false;
  bool isSaving = false;
  String? error;
  ManagerPrivacySummary? privacy;

  Future<void> load() async {
    isLoading = privacy == null;
    error = null;
    notifyListeners();
    try {
      privacy = await _repository.getPrivacy();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load privacy settings.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestExport() {
    return _mutate(
      () => _repository.requestExport(),
      'Failed to request export.',
    );
  }

  Future<bool> requestDeletion({String reason = ''}) {
    return _mutate(
      () => _repository.requestAccountDeletion(reason: reason),
      'Failed to request account deletion.',
    );
  }

  Future<bool> cancelDeletion() {
    return _mutate(
      () => _repository.cancelAccountDeletion(),
      'Failed to cancel account deletion.',
    );
  }

  Future<bool> _mutate(
    Future<ManagerPrivacySummary> Function() action,
    String fallback,
  ) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      privacy = await action();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(e, fallback: fallback);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
