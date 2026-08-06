# Health Constraints Current State

Baseline captured on 2026-08-04 before the safety repair.

## Architecture inventory

Domain writes are owned by the feature services. They persist the domain model and publish a `HealthStateTriggers` event through `HealthStateEventPublisher`. The publisher uses `transaction.on_commit`, then `HealthStateOrchestrator` optionally recomputes constraints, rebuilds `UnifiedHealthState`, records a delta, and refreshes Notification Hub plans.

| Operation | Owning service | Main write | Trigger | Constraint impact | Current Flutter read |
| --- | --- | --- | --- | --- | --- |
| Meal create/update/delete | `MealFinalizationService` / `NutritionLoggingService` | `MealLog`, components, nutrition snapshots | `meal_*` | none; state projection only | nutrition summary and dashboard read models |
| Drink create/update/delete | `WaterService` | `WaterLog` | `water_*` | none; state projection only | hydration summary and dashboard read models |
| Workout create/update/delete | `ActivityService` | `ActivityLog` | `activity_*` | none; state projection only | activity and dashboard read models |
| Steps create/update/delete | `StepsService` | `StepLog` | `steps_*` | none; state projection only | activity/steps and dashboard read models |
| Sleep create/update/delete | `SleepService` | `SleepLog` | `sleep_*` | none; state projection only | sleep and dashboard read models |
| Medication status | medication dose workflow | `ConditionMedicationLog` | `medication_adherence_changed` | medication constraints | medication and dashboard read models |
| Chronic measurement | `ConditionMeasurementWorkflowService` | `HealthIndicatorRecord`, evaluation, alerts | `condition_reading_logged` | monitoring constraints | chronic summary and unified state |
| Condition add/edit/delete | `ConditionSetupService` | `UserCondition`, targets/restrictions | `user_condition_updated` | full constraint recompute | chronic and dashboard read models |
| Nutrition/micronutrient target | `MicronutrientService` | `UserNutrientTarget` | `user_nutrient_target_changed` | previously nutrition only | micronutrient/nutrition APIs |
| Profile goal update | `UserProfileService` | `UserProfile` | `user_profile_updated` | full constraint recompute | tracker and dashboard read models |

## Write and read paths

The materialized path is `ConstraintSourceCollector -> ConstraintConflictResolver -> ConstraintMaterializer -> ResolvedTrackerConstraint -> ConstraintReadService -> UnifiedHealthState`. `ResolvedTrackerConstraint` stores source links, reason, priority, validity dates, and source traces.

The legacy path is `ConditionConstraintEngine.build_effective_constraints`. Before this repair, `HealthStateProjectionService` used the legacy output as fallback values for calories, hydration, steps, burn, and chronic summary metadata. Notification Hub also recalculated an activity-adjusted hydration target independently.

Known materialized consumers before migration: constraint API, sleep service, and part of `HealthStateProjectionService`. Known independent consumers: `ConditionConstraintEngine`, `HealthConstraintEngine`, Notification Hub hydration compiler, daily health progress profile fallbacks, and some read-model profile fallbacks.

## Confirmed inconsistencies

- Lipid storage contract is `value_1=LDL`, `value_2=HDL`, `value_3=triglycerides`, but the constraint collector treated `value_2` as triglycerides.
- `ConstraintRecomputeDispatcher` wrote `sync_mode` and `metadata` fields that did not exist on `ConstraintResolutionRun`.
- A queued constraint dispatch created one placeholder run and a second materialization run.
- `user_nutrient_target_changed` recomputed nutrition only, omitting micronutrients.
- Meal finalization explicitly published health-state work with `synchronous=False`.
- `core/tasks.py` used a process-local daemon thread when Celery was unavailable on PostgreSQL.
- `HealthTrackerCoordinator` silently built unpersisted current/history projections when materialized state was absent.
- Active constraint reads did not enforce effective validity windows.

## Baseline tests and timing

The combined constraints/chronic/orchestration/Notification Hub test command exceeded the 120 second baseline timeout without a final result. This is recorded as `timeout`, not success. The repair is verified with smaller suites after each phase. No stable pre-change query-count baseline was available; targeted query measurements are reported with the final verification.

## Post-repair status

The repair is now implemented. Runtime effective-target reads use
`EffectiveConstraintReader`, critical health-state updates are synchronous and
persisted, missing state uses `HealthStateBootstrapService`, lipid fields use a
single typed accessor, and Notification Hub consumes the same active hydration
target as Home and the hydration summary.

The legacy engine remains diagnostic-only because development-data comparison
still reports legacy-only and seven unexplained rows. See
`docs/health_constraints_repair_report.md` for exact test results, parity
counts, performance samples, migrations, and rollout risks.
