# Medications Feature

This feature uses one Flutter flow for both manual medications and
condition-linked medications.

## Source Type

The add/edit screen receives the entry context and sends it to the shared API:

- `source_type="manual"` for the Medications page.
- `source_type="condition"` with `user_condition_id` for chronic-condition
  detail pages.

Both paths use the same typed models, repository, controller, screens, widgets,
and reminder sync path.

## Reminder Sync

The backend remains the schedule source of truth. After create, edit,
deactivate, or snooze, `MedicationsController` fetches
`/api/medications/reminder-sync/` and passes the normalized plans to
`NotificationsService.syncMedicationReminders(...)` for local notification
projection.

## Today Plan And Adherence

Today dose rows come from `/api/medications/today/`, so dose actions update
concrete backend dose logs. Adherence cards read the backend summaries instead
of calculating independent UI-only medication state.

