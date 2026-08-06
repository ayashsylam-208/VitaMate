import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../data/manager_repository.dart';
import '../models/manager_models.dart';

class ManagerOverviewController extends ChangeNotifier {
  ManagerOverviewController({ManagerRepository? repository})
    : _repository = repository ?? ManagerRepository();

  final ManagerRepository _repository;

  bool isLoading = false;
  String? error;
  ManagerOverview? overview;

  Future<void> load() async {
    isLoading = overview == null;
    error = null;
    notifyListeners();
    try {
      overview = await _repository.getOverview();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load My VitaMate.',
        statusMessages: const <int, String>{
          404:
              'My VitaMate API is not available on the running backend. Restart Django after pulling the latest code.',
          500:
              'The backend failed while loading My VitaMate. Run migrations, then restart Django.',
        },
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
