import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/habits/models/unhealthy_habit.dart';

void main() {
  test('parses unhealthy habits overview envelope', () {
    final overview = UnhealthyHabitsOverview.fromEnvelope({
      'data': {
        'summary': {
          'active_count': 1,
          'logs_today': 2,
          'relapses_today': 0,
          'points_today': 5,
        },
        'support_message': 'Supportive message',
        'habits': [
          {
            'id': 10,
            'habit_type': 'caffeine',
            'label': 'Caffeine',
            'title': 'Caffeine',
            'goal_type': 'reduce',
            'status': 'active',
            'is_setup': true,
            'baseline': {
              'initial_frequency': 400,
              'initial_quantity': 400,
              'unit': 'mg',
              'common_trigger': 'study',
            },
            'plan': {
              'daily_limit': 300,
              'reduction_percentage': 25,
              'cutoff_time': '18:00',
              'plan_stage': 'Reduce caffeine',
              'healthy_replacement_required': false,
              'reminder_time': '14:00',
            },
            'progress': {
              'today_value': 120,
              'daily_limit': 300,
              'adherence_percent': 100,
              'improvement_percent': 70,
              'relapse_count': 0,
              'support_message': 'Keep tracking',
              'logs_today': [
                {
                  'id': 1,
                  'logged_at': '2026-05-07T10:00:00Z',
                  'quantity': 1,
                  'unit': 'mg',
                  'trigger': 'study',
                  'is_relapse': false,
                  'is_within_limit': true,
                  'caffeine_mg': 120,
                }
              ],
            },
            'reminders': [
              {
                'id': 7,
                'time_of_day': '14:00',
                'message': 'Check caffeine',
                'is_active': true,
              }
            ],
          }
        ],
      },
      'meta': {'is_stale': false, 'request_id': 'req-1'},
    });

    expect(overview.summary.activeCount, 1);
    expect(overview.habits.single.id, 10);
    expect(overview.habits.single.progress.todayValue, 120);
    expect(overview.habits.single.reminders.single.timeOfDay, '14:00');
  });
}
