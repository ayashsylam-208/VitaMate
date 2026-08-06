import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/habits/models/unhealthy_habit.dart';
import 'package:vitamate/features/habits/presentation/mappers/habit_ui_mapper.dart';
import 'package:vitamate/features/habits/presentation/widgets/habit_overview_card.dart';

void main() {
  test('setup-required habit has friendly action and no failure state', () {
    final model = HabitUiMapper.mapHabit(
      const UnhealthyHabit.empty('caffeine', 'Caffeine'),
    );

    expect(model.displayState, HabitDisplayState.setupRequired);
    expect(model.primaryAction, HabitPrimaryActionType.setup);
    expect(model.primaryMetric, isNull);
    expect(model.statusLabel, 'Set up a personal plan');
  });

  test('paused habit exposes continue plan as primary action', () {
    final model = HabitUiMapper.mapHabit(_habit(status: 'paused'));

    expect(model.displayState, HabitDisplayState.paused);
    expect(model.primaryAction, HabitPrimaryActionType.resume);
    expect(model.primaryActionLabel, 'Continue plan');
    expect(model.primaryMetric, isNull);
  });

  testWidgets('setup-required card shows Set up without 0 percent', (
    tester,
  ) async {
    final model = HabitUiMapper.mapHabit(
      const UnhealthyHabit.empty('smoking', 'Smoking'),
    );
    await tester.pumpWidget(_wrapCard(model: model));

    expect(find.text('Set up'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('collapsed card has one primary button and hides details', (
    tester,
  ) async {
    final model = HabitUiMapper.mapHabit(_habit());
    await tester.pumpWidget(_wrapCard(model: model));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Edit plan'), findsNothing);
    expect(find.text('Pause this plan'), findsNothing);
    expect(find.text('What led to it?'), findsNothing);
  });

  testWidgets('expanded card reveals plan details and secondary actions', (
    tester,
  ) async {
    final model = HabitUiMapper.mapHabit(_habit());
    await tester.pumpWidget(_wrapCard(model: model, expanded: true));

    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Edit plan'), findsOneWidget);
    expect(find.text('Pause this plan'), findsOneWidget);
  });
}

Widget _wrapCard({required HabitCardViewModel model, bool expanded = false}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HabitOverviewCard(
            model: model,
            expanded: expanded,
            busy: false,
            onToggleExpanded: () {},
            onPrimaryAction: () {},
            onEditPlan: () {},
            onPauseOrResume: () {},
          ),
        ),
      ),
    ),
  );
}

UnhealthyHabit _habit({
  String habitType = 'caffeine',
  String status = 'active',
  String evaluationStatus = 'within_plan',
}) {
  return UnhealthyHabit.fromJson({
    'id': 10,
    'habit_type': habitType,
    'label': habitType == 'fast_food'
        ? 'Fast Food'
        : habitType == 'smoking'
        ? 'Smoking'
        : 'Caffeine',
    'title': habitType,
    'goal_type': 'reduce',
    'status': status,
    'is_setup': true,
    'baseline': {
      'initial_frequency': habitType == 'fast_food' ? 3 : 300,
      'initial_quantity': habitType == 'fast_food' ? 3 : 300,
      'unit': habitType == 'fast_food' ? 'meals' : 'mg',
      'common_trigger': 'work',
    },
    'plan': {
      'daily_limit': habitType == 'fast_food' ? null : 240,
      'weekly_limit': habitType == 'fast_food' ? 2 : null,
      'reduction_percentage': 20,
      'cutoff_time': habitType == 'caffeine' ? '18:00' : '',
      'plan_stage': 'Plan active',
      'healthy_replacement_required': false,
      'reminder_time': '14:00',
    },
    'progress': {
      'today_value': 120,
      'week_value': 1,
      'daily_limit': habitType == 'fast_food' ? null : 240,
      'weekly_limit': habitType == 'fast_food' ? 2 : null,
      'adherence_percent': 100,
      'improvement_percent': 30,
      'relapse_count': 0,
      'top_trigger': 'work',
      'support_message': 'Keep going',
      'logs_today': [
        {
          'id': 1,
          'logged_at': '2026-05-07T10:00:00Z',
          'quantity': 1,
          'unit': 'servings',
          'trigger': 'work',
          'is_relapse': false,
          'is_within_limit': true,
          'caffeine_mg': 120,
          'food_name': 'Coffee',
        },
      ],
    },
    'reminders': [
      {
        'id': 1,
        'time_of_day': '14:00',
        'message': 'Check plan',
        'is_active': true,
      },
    ],
    'evaluation': {
      'status': evaluationStatus,
      'feedback': {'message': 'Caffeine plan updated'},
    },
  });
}
