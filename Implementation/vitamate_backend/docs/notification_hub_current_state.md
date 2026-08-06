# Notification Hub Current State

## Scope and delivery model

VitaMate currently uses backend-owned planning with device-local delivery:

1. Django compilers read tracker, health-state, medication, and motivation data.
2. `NotificationHubPlanner.sync` persists plans and returns a 72-hour snapshot.
3. Flutter receives the snapshot and schedules Android local notifications.
4. Foreground intents are returned as `in_app_events`.

There is no configured push provider in this flow. The backend does not directly deliver an Android notification.

## Event types and delivery modes

- Health: `health_warning`, medication dose and snooze plans.
- Routine: hydration, meal, activity, sleep, step, and habit reminders.
- Motivation: first-meal, mission-near-complete, streak-at-risk, badge-near-unlock, and level-progress nudges.
- Celebration: points, mission, badge, level, and streak experience events.
- Delivery modes: Android local schedule, foreground in-app presentation, and notification-tap deep link.

## Existing states

Plans currently use `planned`, `scheduled`, `suppressed`, `cancelled`, `expired`, `delivered`, and `failed`. Device reports use `scheduled_local`, `foreground_suppressed`, `opened`, `dismissed`, `delivered`, `schedule_failed`, and `cancelled_local`.

The current model overloads `suppressed`: foreground in-app routing and policy suppression share the same state. Presentation does not distinguish visible presentation from acknowledgment.

## Current flow inventory

| Scenario | Current behavior before repair | Gap |
| --- | --- | --- |
| Critical warning, foreground | Compiler emits an alert intent and sync returns it in `in_app_events`. Flutter presenter returns immediately for `health_warning`, while the controller reports `foreground_suppressed`. | Critical warning is silently lost. |
| Critical warning, background | Flutter schedules it on `health_critical_v2` as a local Android notification. | Delivery depends on local permission/capability; permission reporting is currently inaccurate. |
| Routine reminder | Backend returns recurring schedule specification; Flutter schedules local occurrences. | Every sync cancels and recreates unchanged plans. |
| Motivation nudge | Backend applies historical quota/cooldown checks and returns local or foreground plan. | Same-sync accepted candidates are not counted; route equality suppresses without a 90-minute comparison. |
| Celebration | Unacknowledged motivation experience events are compiled and shown in foreground. | Expiry is not filtered consistently and Hub acknowledgment does not reach the source event. |
| First device | First registered user device is marked primary. | No database uniqueness constraint for active primary device. |
| Second device | It remains non-primary at registration. | Sync does not enforce primary status and still returns schedulable plans. |
| Permission denied | Registration can store false, but Flutter's sync snapshot hardcodes notification authorization to true. | Backend can plan local delivery that the device cannot execute. |
| Unchanged sync | Existing plans are upserted and Flutter cancels/reschedules all returned plans. | Duplicate `scheduled_local` reports inflate motivation quota history. |
| Changed sync | Existing row is overwritten and local plan recreated. | No revision or payload fingerprint identifies a real change. |
| Flutter acknowledgment | Reports are stored only as generic event types. | No explicit `acknowledged` outcome or source Motivation propagation. |
| Foreground suppression | Intent is stored as `suppressed`; controller reports `foreground_suppressed`. | Foreground is incorrectly treated as a suppression policy. |
| Expired event | Plan has `expire_at`, but celebration compilation/presentation does not consistently reject expired rows. | Expired celebration can repeat. |
| App restart | Bootstrap initializes Hub and syncs when a session exists. | Permission requests repeat automatically; scheduling registry cannot diff revisions. |

## Device and permission fields

`NotificationDevice` stores installation ID, user, platform, timezone, locale, app version, `is_primary`, `notifications_authorized`, `exact_alarm_authorized`, and last-seen/sync timestamps. It has no active/revoked state or assignment version.

Flutter currently requests notification and exact-alarm permissions during Hub initialization and reports `notifications_authorized: true` unconditionally. This is not a trustworthy capability snapshot.

## Acknowledgment and sound behavior

The Motivation API can acknowledge source experience events, but Notification Hub reports do not call it. Android notification sound is controlled by versioned v2 channels. Foreground point/mission feedback uses Android `ToneGenerator` on `STREAM_MUSIC`, so media volume can mute it and it is not separated as notification/sonification feedback.

## Baseline verification

Executed before behavior changes on 2026-08-05:

- `python manage.py test gamification notification_hub --keepdb`: 26 tests passed in 60.992 seconds; 0 Django system-check issues.
- `flutter test test/features/motivation test/features/home/home_motivation_card_test.dart`: 11 tests passed.
- `flutter analyze lib/core/notification_hub lib/features/motivation`: no issues.
- Manual Android scheduling/sound/device verification was not executed during baseline collection.

## Release-blocking gaps

1. Foreground health warnings can be lost.
2. Non-primary devices can schedule plans.
3. Permission state is hardcoded.
4. Motivation quota is not same-sync safe.
5. Routine proximity is route-only rather than time/category based.
6. Local scheduling is not revision/diff based.
7. Celebration expiry and source acknowledgment are incomplete.
8. Report events are not idempotent and state transitions are not validated.
9. Notification-specific Flutter tests are missing.
