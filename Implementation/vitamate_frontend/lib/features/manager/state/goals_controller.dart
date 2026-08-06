import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../data/manager_repository.dart';
import '../models/manager_models.dart';

class GoalsController extends ChangeNotifier {
  GoalsController({ManagerRepository? repository})
    : _repository = repository ?? ManagerRepository();

  final ManagerRepository _repository;

  bool isLoading = false;
  String? error;
  List<ManagerGoal> goals = const [];

  Future<void> load() async {
    isLoading = goals.isEmpty;
    error = null;
    notifyListeners();
    try {
      goals = await _repository.getGoals();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load goals.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveCustomGoal(String key, double? value) async {
    error = null;
    notifyListeners();
    try {
      final updated = await _repository.updateGoal(key, value);
      goals = goals
          .map((goal) => goal.key == key ? updated : goal)
          .toList(growable: false);
      notifyListeners();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to update goal.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetAll() async {
    error = null;
    notifyListeners();
    try {
      goals = await _repository.resetGoals();
      notifyListeners();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to reset goals.',
      );
      notifyListeners();
      return false;
    }
  }
}
