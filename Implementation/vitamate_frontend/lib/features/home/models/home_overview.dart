import '../../../shared/models/api_result.dart';
import '../../chronic_conditions/models/chronic_condition.dart';
import 'dashboard_data.dart';

class HomeOverview {
  const HomeOverview({
    required this.dashboard,
    required this.conditionsCenter,
    required this.meta,
  });

  final DashboardData dashboard;
  final List<ChronicCondition> conditionsCenter;
  final ApiMeta meta;
}
