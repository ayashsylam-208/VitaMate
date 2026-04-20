import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/home/models/dashboard_data.dart';

void main() {
  test('dashboard data parses chronic summary safely', () {
    final data = DashboardData.fromDashboard({
      'gamification': {'points': 18},
      'activity': {'steps': 4200},
      'hydration': {'current': 1.6},
      'summary': {'calories_consumed': 1400},
      'chronic_conditions': {
        'count': 2,
        'labels': ['Diabetes / Prediabetes', 'Hypertension / High Blood Pressure'],
        'adherence_percent': 75,
        'active_medications_today': 3,
        'pending_doses_today': 1,
        'applied_summaries': ['Daily sodium limit set to 1500 mg.'],
        'disclaimer': 'Supportive self-management only.',
      },
    });

    expect(data.points, 18);
    expect(data.chronicSummary.count, 2);
    expect(data.chronicSummary.pendingDosesToday, 1);
    expect(data.chronicSummary.labelsSummary, contains('Diabetes'));
  });
}
