# Core Maintenance Map

## Domain Map
- `core/models/nutrition.py`: food catalog, nutrition facts, servings, meal logs, water logs
- `core/models/tracking.py`: exercise, activity, steps, sleep
- `core/models/legacy.py`: legacy medicines and habits compatibility tables
- `core/models/chronic.py`: chronic-condition catalog, user conditions, targets, indicators, alerts, condition medications
- `core/models/constraints.py`: resolved execution-layer tracker constraints and recompute audit

## API Module Map
- `core/api/nutrition/`: foods, meals, nutrition facts, serving options
- `core/api/hydration/`: water and beverage logging
- `core/api/tracking/`: steps, activities, sleep, exercises
- `core/api/chronic/`: condition catalog, user conditions, readings, summaries
- `core/api/medication/`: medication plans, schedules, adherence flows
- `core/api/constraints/`: resolved constraints and recompute endpoints
- `core/api/legacy/`: legacy medicine and habit endpoints
- `core/api/system/`: dashboard, history, health check

## Service Ownership
- `core/services/nutrition/`: nutrition catalog and meal workflows
- `core/services/hydration/`: water and beverage workflows
- `core/services/tracking/`: activity, steps, sleep, dashboard coordination
- `core/services/chronic/`: chronic-condition workflows, rule interpretation, readings, alerts
- `core/services/medication/`: medication plans, schedules, dose workflow, reminder sync
- `core/services/constraints/`: resolved constraint collection, conflict resolution, materialization, reads

## Repository Ownership
- `core/repositories/nutrition/`: food catalog, food search, meal logs
- `core/repositories/hydration/`: water logs
- `core/repositories/tracking/`: activity, steps, sleep
- `core/repositories/chronic/`: chronic-condition read/write access
- `core/repositories/medication/`: medication plans, schedules, logs
- `core/repositories/dashboard/`: dashboard/history read aggregation

## Source of Truth vs Compatibility
- Primary nutrition data: `FoodItem`, `NutritionFacts`, `NutritionServingOption`, `MealLog`
- Primary chronic/medication data: `UserCondition`, `HealthTarget`, `HealthIndicatorRecord`, `ConditionMedication*`
- Execution layer: `ResolvedTrackerConstraint`, `ConstraintResolutionRun`, `ConstraintSourceTrace`
- Compatibility layer only: `Medicine`, `MedicineLog`, `Habit`, `HabitLog`

## Compatibility Rules
- Keep `from core.models import ...` as the public model barrel.
- Keep old module imports under:
  - `core.views`
  - `core.serializers`
  - `core.chronic_views`
  - `core.medication_views`
  - `core.constraint_views`
  - `core.services.*`
  - `core.repositories.*`
- Prefer new structured imports for all new work.
