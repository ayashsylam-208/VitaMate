import 'package:dio/dio.dart';

import '../../chronic_conditions/models/chronic_condition.dart';
import '../models/dashboard_data.dart';
import '../models/home_overview.dart';
import 'home_api.dart';

class HomeRepository {
  HomeRepository({HomeApi? api}) : _api = api ?? const HomeApi();

  final HomeApi _api;

  Future<HomeOverview> getOverview({CancelToken? cancelToken}) async {
    final envelope = await _api.getOverview(cancelToken: cancelToken);
    final data = envelope.data;
    final overviewDashboard = DashboardData.fromOverview(data);
    final dashboard = envelope.meta.isStale && !overviewDashboard.hasTrackerMetrics
        ? DashboardData.fromDashboard(
            await _api.getDashboardFallback(cancelToken: cancelToken),
          )
        : overviewDashboard;

    return HomeOverview(
      dashboard: dashboard,
      conditionsCenter: (data['conditions_center'] is List)
          ? (data['conditions_center'] as List)
                .whereType<Map>()
                .map(
                  (item) => ChronicCondition.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <ChronicCondition>[],
      meta: envelope.meta,
    );
  }
}
