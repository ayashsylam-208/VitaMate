# Health Constraints Repair Report

Report date: 2026-08-04

## 1. Original problems

- Lipid measurements were stored as `value_1=LDL`, `value_2=HDL`, and
  `value_3=triglycerides`, while the constraint collector interpreted
  `value_2` as triglycerides.
- `ConstraintRecomputeDispatcher` wrote observability fields that did not
  exist on `ConstraintResolutionRun`, and queued execution could create
  misleading duplicate run records.
- Critical health-state refreshes could use a process-local background thread,
  allowing an API write to return before `UnifiedHealthState` was current.
- `ConditionConstraintEngine`, materialized constraints, projection fallbacks,
  and feature-specific defaults could produce different effective targets.
- Micronutrient target changes did not fan out to the micronutrient projection.
- Missing materialized state could be hidden by an unpersisted coordinator
  projection.
- Notification hydration decisions and some dashboard values did not always
  use the same effective target.
- Tracker `auto_now_add` dates used the host date rather than Django's local
  health day at the UTC/local date boundary.

## 2. Modified files

The health repair changed these main production areas. The worktree also
contains unrelated pre-existing changes; they are not attributed to this
repair.

- Models: `core/models/constraints.py`, `core/models/health_state.py`,
  `core/models/nutrition.py`, `core/models/tracking.py`, and
  `core/models/__init__.py`.
- Constraint pipeline: `core/services/constraints/constraint_materializer.py`,
  `constraint_read_service.py`, `constraint_recompute_dispatcher.py`,
  `constraint_resolution_service.py`, `constraint_source_collector.py`, and
  `core/services/constraints/__init__.py`.
- Chronic domain: `core/services/chronic/chronic_condition_service.py`,
  `condition_constraint_engine.py`, `condition_indicator_service.py`,
  `condition_integration_coordinator.py`, `condition_points_evaluator.py`, and
  `condition_evaluators/dyslipidemia.py`.
- Orchestration: `health_state_event_publisher.py`,
  `health_state_orchestrator.py`, `health_state_projection_service.py`,
  `read_model_service.py`, `tracker_dependency_map.py`,
  `health_tracker_coordinator.py`, and `core/tasks.py`.
- Tracker consumers: hydration, nutrition, micronutrients, activity, steps,
  sleep, medication adherence, daily health progress, and movement services.
- API read models: constraint, hydration, nutrition, tracking, medication, and
  system serializers/views where active targets or state metadata are exposed.
- Downstream consumers: `notification_hub/services/compilers.py`,
  `gamification/services/points_service.py`, and
  `gamification/services/motivation_service.py`.
- Tests under `core/tests/chronic`, `core/tests/constraints`,
  `core/tests/orchestration`, `core/tests/hydration`, and
  `core/tests/misc`.

## 3. New files

- `core/services/chronic/lipid_panel_values.py`
- `core/services/chronic/condition_runtime_summary_service.py`
- `core/services/constraints/effective_constraint_reader.py`
- `core/services/constraints/constraint_candidate_validator.py`
- `core/services/constraints/constraint_engine_comparison_service.py`
- `core/services/orchestration/health_state_bootstrap_service.py`
- `core/management/commands/_health_command_utils.py`
- `core/management/commands/audit_lipid_measurements.py`
- `core/management/commands/compare_constraint_engines.py`
- `core/management/commands/rebuild_user_constraints.py`
- `core/management/commands/rebuild_unified_health_state.py`
- `core/management/commands/audit_constraint_consistency.py`
- `core/management/commands/report_stale_health_states.py`
- `core/tests/chronic/test_lipid_panel_mapping.py`
- `core/tests/constraints/test_health_maintenance_commands.py`
- `core/tests/orchestration/test_tracker_dependency_map.py`
- `core/tests/orchestration/test_daily_health_progress.py`
- `docs/health_constraints_current_state.md`
- `docs/health_state_frontend_contract.md`
- This report.

## 4. Migrations

- `0041_constraint_resolution_run_observability`: adds mode, metadata,
  correlation/idempotency keys, retries, failure fields, affected trackers,
  normalized statuses, and unique non-null idempotency keys.
- `0042_health_state_run_observability`: adds correlation/idempotency, retries,
  and structured failure fields to health-state computation runs.
- `0043_tracker_local_date_defaults`: changes meal, water, activity, steps, and
  sleep default dates to `timezone.localdate` without rewriting history.

All three migrations were applied successfully to the local development
database. `makemigrations --check --dry-run` reports no missing migration.

## 5. Exact lipid mapping repair

`LipidPanelValues` is now the only production interpretation boundary:

```text
value_1 -> ldl_mg_dl
value_2 -> hdl_mg_dl
value_3 -> triglycerides_mg_dl
```

The collector, condition indicator, dyslipidemia evaluator, chronic facade,
and their evidence payloads consume the typed object. A repository search
found no production service outside this accessor interpreting the generic
fields. Historical rows were not rewritten because their ordering cannot be
proven from storage alone. The audit command reports three current lipid rows,
all structurally valid, and performs no repair unless explicitly requested.

## 6. Old versus new orchestration

Old critical flow:

```text
domain write -> on_commit -> optional process-local Thread
             -> constraints/projection may finish after API response
```

New critical flow:

```text
domain write and commit
  -> idempotent synchronous ConstraintRecomputationService
  -> persisted UnifiedHealthState projection
  -> typed result with correlation ID/state version
  -> API response and immediate read from persisted state
```

Secondary notification planning can still occur after commit, but no critical
health truth depends on a process-local thread. Recompute runs have explicit
success/failure state, correlation, idempotency, timing, and error metadata.
Duplicate deliveries return the existing result instead of publishing another
active state.

## 7. Consumers migrated to EffectiveConstraintReader

- Unified health-state projection and dashboard read models.
- Nutrition calories/macros/limits and micronutrient targets.
- Hydration, steps, activity burn, sleep, and daily health progress.
- Tracking serializer goal presentation.
- Chronic integration compatibility facade.
- Notification Hub hydration compiler.
- Motivation focus and points checks.

The reader filters status and validity windows, resolves deterministically,
returns value/unit/source/reason/priority/expiry, and has a bulk method to avoid
one query per metric. It never calls the legacy engine as a fallback.

## 8. Remaining legacy-engine consumers

`ConditionConstraintEngine` remains in exactly two non-production roles:

- compatibility export from `core/services/__init__.py`;
- diagnostic comparison in `ConstraintEngineComparisonService`.

The development-data comparison is not yet parity-clean:

| Status | Count |
| --- | ---: |
| exact match | 38 |
| explainable difference | 1 |
| both missing | 475 |
| legacy only | 291 |
| materialized only | 18 |
| unexplained difference | 7 |

The seven unexplained rows are limited to hydration rounding and legacy versus
materialized steps/activity defaults for users 1, 2, 127, and 128. These need
business/data review before deleting the engine. No runtime screen silently
uses the legacy values.

## 9. Tests added or expanded

- LDL/HDL/triglyceride field ownership and missing-value regression tests.
- Constraint validity, bulk read, source traceability, unit validation,
  idempotency, rollback, superseding, and real concurrent recompute tests.
- Dispatcher synchronous/queued/idempotency/failure/retry metadata tests.
- Tracker dependency validation and micronutrient fan-out tests.
- Deterministic meal projection, duplicate event, rollback, bootstrap, and
  failure recovery tests.
- Chronic condition deactivation preserves history while superseding active
  constraints and refreshing state.
- Home/hydration and nutrition/UnifiedHealthState active-target contract tests.
- Notification Hub effective hydration target and suppression tests.
- Local health-day progress tests protecting the UTC/local date boundary.
- Management command dry-run tests.

## 10. Verification commands and results

```text
python manage.py test core.tests.chronic core.tests.constraints \
  core.tests.orchestration --noinput -v 1
53 tests, OK

python manage.py test notification_hub.tests --keepdb --noinput -v 1
9 tests, OK

python manage.py test <five hydration/nutrition/micronutrient contract tests>
5 tests, OK

python manage.py check
0 issues

python manage.py makemigrations --check --dry-run
No changes detected

python manage.py migrate --noinput
0041, 0042, 0043 applied successfully
```

All six maintenance commands completed against development data in `--dry-run`
mode with exit code 0. A broader 175-test regression command exceeded the
10-minute execution limit before producing a final summary. No failure had
been printed at timeout, but it is recorded as incomplete, not passed.

## 11. Query and timing measurements

Measurements are development-machine samples, not production benchmarks.

| Operation | Before | After |
| --- | --- | --- |
| Micronutrient overview | 44 queries, about 312 ms | 27 queries, 53-84 ms |
| Micronutrient target mutation | 274-304 queries | 203-287 queries, depending on linked plan work |
| Constraint recompute API | no stable baseline | 20 queries, about 48 ms sampled |
| Hydration summary after activity | no stable baseline | 12 queries, 66 ms sampled |
| Home steady read | 32 queries observed | 32 queries, 165 ms sampled |
| First missing-state bootstrap | unpersisted fallback possible | 132-154 queries, 500-601 ms, persisted |
| Meal write | could return before projection | 29 queries/78 ms write plus about 370 ms synchronous projection |

Bulk effective-constraint lookup removes one query per requested macro or
micronutrient. The bootstrap path remains intentionally heavier because it
materializes constraints and all health domains rather than weakening
consistency.

## 12. Remaining risks

- Legacy/materialized parity is not complete, especially legacy-only macro and
  tracker defaults. The engine must not be deleted yet.
- A strict database uniqueness constraint for every active effective scope was
  intentionally deferred until duplicate/legacy data cleanup. Transactional
  locking and idempotent materialization protect normal writes now.
- Existing rows with host-date-derived tracker dates were not rewritten; only
  new records use the corrected local-date default.
- Some historical manual activity rows have no event timestamp, so stale-state
  reporting marks a timestamp coverage gap rather than guessing freshness.
- First-time bootstrap and micronutrient target updates remain query-heavy.
- The full 175-test suite did not finish within the available timeout.
- Clinical source identifiers remain nullable where the existing project did
  not provide a documented source; absence is audit-visible and not fabricated.

## 13. Manual verification

1. Run `python manage.py check` and `python manage.py showmigrations core`.
2. Run all six maintenance commands with `--dry-run`; archive JSON output.
3. For a user with each supported condition, run
   `compare_constraint_engines --user-id <id> --format json --dry-run`.
4. Log a meal, drink, workout, steps, sleep, and medication dose, then
   immediately compare the tracker summary, Home, and UnifiedHealthState.
5. Change a micronutrient target and verify both nutrition and micronutrient
   state versions advance once.
6. Disable a chronic condition and verify its active rows are superseded,
   history remains, and Notification Hub replans.
7. Test around local midnight and confirm all five tracker records use the
   Django local health date.

## 14. Rollback strategy

- Application rollback: deploy the prior code while retaining additive fields;
  older code ignores them. Do not remove audit rows during rollback.
- Migration rollback: `0043` can be reversed to `auto_now_add`; `0042` and
  `0041` can be reversed only after confirming no operational tooling depends
  on their run metadata. Database backup is required first.
- Data rollback: materialization supersedes rows rather than deleting history.
  Rebuild a selected user from source data with the recovery commands.
- Do not rewrite lipid history automatically. Any later correction must use an
  audited, provable mapping and a separate data migration.

## 15. Assumptions

- Existing clinical thresholds and medication points (`+3` on time, `+1` late,
  `-2` missed) are business rules and were not rebalanced.
- PostgreSQL is the authoritative runtime database.
- Android notifications remain backend-planned and locally scheduled by
  Flutter; this repair changes target consistency, not delivery architecture.
- `ResolvedTrackerConstraint` plus the documented backend default source is
  authoritative even where the legacy comparison currently differs.
- Safe incremental migration takes priority over deleting compatibility code or
  enforcing constraints against unclean historical data.
