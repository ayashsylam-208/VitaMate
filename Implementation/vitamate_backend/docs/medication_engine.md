# VitaMate Medication Engine

The medication feature uses one canonical backend flow for both the Medications
page and chronic-condition medication entry points.

## Canonical Plan

`ConditionMedication` is the user medication plan record. A manual medication
uses `source_type="manual"` and `user_condition=null`. A chronic-condition
medication uses `source_type="condition"` and links to the selected
`UserCondition`.

Schedules and dose logs are shared by both entry points:

- `ConditionMedicationSchedule` stores active reminder rules.
- `ConditionMedicationLog` stores concrete expected dose instances.

Views do not write tracker data directly. Write operations go through medication
services, and dashboard/history read medication state through the coordinator
and tracker adapter.

## Dose Generation

`MedicationScheduleService.generate_pending_doses()` expands active fixed
schedules into pending `ConditionMedicationLog` rows for a requested time
window. It does not duplicate existing logs because `(medication, scheduled_for)`
is unique.

PRN/as-needed schedules are stored for reference and reminder sync, but they do
not generate fixed daily expected doses like scheduled medications.

## Dose Workflow

`MedicationDoseWorkflowService` owns dose state changes:

- `taken`, `missed`, and `skipped` are final user states.
- `snoozed` is temporary until `snoozed_until`.
- `overdue` is a system state for pending doses past the schedule grace period.

Inactive medication plans reject user dose actions.

## Adherence

`MedicationAdherenceService` calculates adherence from expected dose logs, not
from taken logs only.

Formula:

`adherence_percent = taken_doses / expected_doses * 100`

`taken` includes the unified `taken` state and legacy compatible
`taken_on_time` / `taken_late` states. Missed, skipped, pending, snoozed, and
overdue doses are reported separately.

## Reminder Sync

The backend does not send push notifications. `MedicationReminderSyncService`
returns a normalized reminder payload from active backend schedules. Flutter
uses that payload to cancel outdated local medication notifications and schedule
the current active reminders.

