import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/network/request_manager.dart';
import '../../chronic_conditions/models/chronic_condition.dart';
import '../data/home_repository.dart';
import '../models/dashboard_data.dart';

class HomeController extends ChangeNotifier {
  HomeController({HomeRepository? repository, RequestManager? requestManager})
    : _repository = repository ?? HomeRepository(),
      _requestManager = requestManager ?? RequestManager();

  final HomeRepository _repository;
  final RequestManager _requestManager;

  bool loading = false;
  String? error;
  bool isStale = false;
  DashboardData data = DashboardData.empty();
  List<ChronicCondition> conditionsCenter = const <ChronicCondition>[];

  Future<void> load() async {
    final lease = _requestManager.beginLatest('home.overview');
    loading = true;
    error = null;
    if (kDebugMode) {
      debugPrint('HomeController.load: start');
    }
    notifyListeners();

    try {
      final overview = await _repository.getOverview(
        cancelToken: lease.cancelToken,
      );
      if (!_requestManager.isCurrent(lease)) {
        return;
      }
      data = overview.dashboard;
      conditionsCenter = overview.conditionsCenter;
      isStale = overview.meta.isStale;
      loading = false;
      if (kDebugMode) {
        debugPrint(
          'HomeController.load: success '
          'points=${data.points} '
          'steps=${data.todaySteps} '
          'waterMl=${data.waterMl} '
          'sleepMinutes=${data.sleepMinutes} '
          'calories=${data.calories} '
          'conditions=${conditionsCenter.length} '
          'isStale=$isStale',
        );
      }
      notifyListeners();
    } catch (e) {
      if (NetworkErrorMapper.isCanceled(e) ||
          !_requestManager.isCurrent(lease)) {
        return;
      }
      loading = false;
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load data. Please try again.',
      );
      if (kDebugMode) {
        debugPrint('HomeController.load: error=$error raw=$e');
      }
      notifyListeners();
    } finally {
      _requestManager.complete(lease);
    }
  }

  @override
  void dispose() {
    _requestManager.cancelAll();
    super.dispose();
  }
}
