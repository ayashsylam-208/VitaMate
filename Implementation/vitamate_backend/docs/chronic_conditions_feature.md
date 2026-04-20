# Chronic Conditions Feature

## Scope
- Supported conditions: `diabetes`, `hypertension`, `hyperlipidemia`
- Supported workflows:
  - create/update/deactivate condition
  - create/update/deactivate medication
  - daily dose actions: `take`, `miss`, `snooze`, `skip`
  - derived chronic-condition targets and dashboard propagation
  - medication adherence points + daily restriction points + streak bonuses

## Backend flow
1. `UserConditionViewSet` manages the user's chronic conditions.
2. `ConditionMedicationViewSet` manages medications linked to one condition.
3. `ConditionMedicationScheduleViewSet` manages daily dose actions.
4. `ConditionIntegrationCoordinator` rebuilds targets and re-evaluates the condition after changes.
5. `ConditionConstraintEngine` merges active-condition rules into safer dashboard targets.
6. `ConditionPointsEvaluator` writes point changes and audit entries.

## Main endpoints
- `GET /api/condition-types/`
- `GET/POST/PATCH /api/user-conditions/`
- `POST /api/user-conditions/<id>/deactivate/`
- `GET/POST/PATCH /api/condition-medications/`
- `POST /api/condition-medications/<id>/deactivate/`
- `GET /api/condition-medication-schedules/today/`
- `POST /api/condition-medication-schedules/<id>/take/`
- `POST /api/condition-medication-schedules/<id>/miss/`
- `POST /api/condition-medication-schedules/<id>/snooze/`
- `POST /api/condition-medication-schedules/<id>/skip/`
- `GET/POST /api/health-indicators/`

## Frontend flow
- Home route surfaces a chronic-conditions card using `dashboard.chronic_conditions`.
- `ChronicConditionsScreen` shows:
  - overview
  - today's medication queue
  - condition list
- `ChronicConditionDetailScreen` shows:
  - condition summary
  - applied limits
  - targets
  - medications
  - alerts

## Reminder integration
- Local reminders are synchronized from active chronic medications by:
  - `NotificationsService.syncChronicMedicationReminders`
- Snoozed doses schedule a one-off reminder with:
  - `NotificationsService.scheduleChronicMedicationSnooze`

## Notes
- This feature supports self-management and does not replace clinician guidance.
- Rule data remains seed/config driven instead of hard-coded in the UI.
