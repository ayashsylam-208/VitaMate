# Nutrition and AI Meal Integration

## Decision

VitaMate treats the AI runtime as a suggestion engine. It may suggest a dish,
ingredients, masks, and confidence values. It never owns final nutrition,
points, hydration, habits, or a saved meal.

The authoritative path is:

```text
Flutter -> Django /api/nutrition/ai-meals/* -> AI runtime /analyze
        -> user confirmation -> Django NutritionFacts
        -> MealFinalizationService -> MealLog + MealLogComponent
        -> points/hydration/habits + integration outbox
```

Flutter never calls the AI runtime. Django sends the internal service token and
requests `auto_weight_mode=try` by default. The runtime may estimate total meal
weight; Django distributes that estimate across detected ingredients by their
suggested ratios. A user-confirmed gram value is still required for every
included component before saving.

## Sources Of Truth

| Concern | Owner |
| --- | --- |
| AI suggestions and confidence | AI runtime |
| Ingredient mapping | `ai_meals.AIIngredientMapping` |
| Nutrient values | `core.NutritionFacts` |
| Saved meal and component snapshots | `MealLog`, `MealLogComponent` |
| Points | gamification ledger |
| Hydration and habit projections | their backend domain services |
| Mobile display | typed Django responses |

Legacy nutrient columns remain temporarily for compatibility, but final meal
snapshots are calculated from canonical `NutritionFacts`. Use
`python manage.py verify_nutrition_catalog` to audit catalog readiness.

## Security And Validation

- Meal, analysis, and private food queries are owner-scoped.
- Global `NutritionFacts` and serving options are read-only for ordinary users.
- Accepted uploads are JPEG, PNG, or WebP, at most 10 MB by default.
- Django verifies the image signature, decodes it with Pillow, enforces pixel
  and dimension limits, applies EXIF orientation, strips metadata, and forwards
  a normalized JPEG.
- The runtime requires `X-VitaMate-Service-Token` with a 32+ character secret.
- The runtime is bound to `127.0.0.1:8010`, has a bounded queue, one concurrent
  analysis by default, and one Uvicorn worker.
- `/readyz` performs an actual pipeline prewarm once and returns 503 if model
  loading fails. `/healthz` only confirms process health.

## Django API

```text
POST  /api/nutrition/ai-meals/analyze/
GET   /api/nutrition/ai-meals/{analysis_id}/
PATCH /api/nutrition/ai-meals/{analysis_id}/
POST  /api/nutrition/ai-meals/{analysis_id}/finalize/
```

Analyze accepts multipart `image` and optional `Idempotency-Key`. Reusing the
same key for one user returns the same persisted analysis session.

Confirmation requires a dish label, meal type, optional consumed time, and at
least one included component with an accessible `food_item_id` and positive
confirmed grams. When automatic weight estimation fails, clients must ask the
user for total meal weight or individual ingredient weights. Unmapped or
unconfirmed components block finalization.

Finalize requires a stable `Idempotency-Key`. Its response contains:

```json
{
  "analysis_id": "uuid",
  "meal": {"id": 44},
  "nutrition_summary": {},
  "hydration_delta_ml": 0,
  "habit_events": [],
  "points_delta": 5,
  "today_summary": {},
  "already_finalized": false
}
```

A retry with the same key returns the existing meal, sets
`already_finalized=true`, and returns `points_delta=0`. A different key after
finalization returns HTTP 409.

## Transaction And Projection Rules

`MealFinalizationService` is the only final save path for manual composite and
AI meals. It locks the user/session as applicable, resolves canonical facts,
creates one meal and its components, writes point transactions idempotently,
projects linked hydration/habits once, and enqueues one deduplicated integration
outbox event.

Outbox events are dispatched after commit. Failed events can be retried with:

```powershell
python manage.py process_integration_outbox --limit 100
```

Deleting a meal reverses source-linked points and removes linked hydration and
habit projections before deleting the meal.

## Runtime Setup On Windows

From `vitamate_backend`:

```powershell
$env:AI_MEALS_SERVICE_TOKEN='replace-with-the-same-random-32-plus-character-token'
.\scripts\install_ai_service.ps1
```

The install script extracts `VitaMate_AI_Backend_Runtime_20260802.zip` outside
the repository, creates an isolated virtual environment, resolves a lock file,
installs it, and runs the vendor readiness checker.

Installation is required once. In local Windows development, `manage.py
runserver` then starts the installed AI runtime automatically, waits for
`/readyz`, and only then starts Django:

```powershell
$env:DJANGO_SETTINGS_MODULE='vitamate_project.settings_dev'
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000 --noreload
```

Set `VITAMATE_SKIP_AI_SERVICE_BOOTSTRAP=1` only when intentionally running
Django without meal photo analysis. `scripts\run_ai_service.ps1` remains
available for isolated runtime diagnostics.

Check the runtime before using the mobile flow:

```powershell
curl.exe http://127.0.0.1:8010/healthz
curl.exe http://127.0.0.1:8010/readyz
```

## Performance And Observability

The initial AI finalize path observed about 190 database queries during the
repair baseline. Batched point synchronization, prefetching, direct projection
reads, and outbox deferral reduced the observed first-finalize path to 40. The
API regression test enforces a maximum of 50; an idempotent retry currently
uses about 15.

Analysis sessions persist raw provider output, model versions, status, expiry,
image hash, provider session ID, and idempotency keys. Final meals carry a
correlation/source reference. The existing HTTP metrics middleware records
request ID, latency, response size, and query count.

## Known Limits

- The supplied AI package is large and must be installed separately; repository
  tests mock its network contract rather than loading GPU models.
- The package evaluation artifacts show limited semantic accuracy (about 28.6%
  top-1 dish and 42.9% top-3 in the included report). UI copy must continue to
  say "AI suggestion" and "Suggested ingredients".
- Automatic weight estimation is attempted, but it remains provisional. If the
  runtime cannot resolve scale or depth reliably, the client must collect manual
  total or ingredient weights before finalization.
- The vendor runtime keeps its own temporary in-memory session, but VitaMate
  does not depend on it for finalization. Django persists the provider response
  and computes final nutrition itself.

## Verification

```powershell
python manage.py makemigrations --check
python manage.py migrate
python manage.py check
python manage.py test core.tests.nutrition --keepdb
python manage.py test core.tests.hydration --keepdb
python manage.py test gamification.tests --keepdb
python manage.py test ai_meals.tests --keepdb

dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/nutrition
```
