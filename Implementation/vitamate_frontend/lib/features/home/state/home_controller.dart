import 'package:flutter/foundation.dart';
import '../data/home_api.dart';
import '../models/dashboard_data.dart';

class HomeController extends ChangeNotifier {
  HomeController({HomeApi? api}) : _api = api ?? const HomeApi();

  final HomeApi _api;

  bool loading = false;
  String? error;
  DashboardData data = DashboardData.empty();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final dashboard = await _api.getDashboard();
      data = DashboardData.fromDashboard(dashboard);

      loading = false;
      notifyListeners();
    } catch (_) {
      loading = false;
      error = 'Failed to load data. Please try again.';
      notifyListeners();
    }
  }
}
