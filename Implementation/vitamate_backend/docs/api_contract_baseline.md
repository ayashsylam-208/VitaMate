# VitaMate Backend API Contract Baseline

This baseline captures the public JSON contracts currently consumed by the Flutter app.
It is used as a regression reference during the gradual Strangler/Adapter migration.

## Auth

### `GET /api/auth/me/`

- Must return account/profile fields used by app settings and onboarding.
- Expected keys (minimum):  
  `username`, `first_name`, `last_name`, `email`, `weight`, `height`, `activity_level`,
  `goal`, `daily_step_goal`, `gender`, `birth_date`, `recommended_sleep_hours`,
  `target_wake_time`, `target_bed_time`, `enable_sleep_improvement`,
  `preferred_activity_type`, `enable_activity_reminders`,
  `activity_reminder_interval_hours`, `enable_water_reminders`,
  `water_reminder_interval_minutes`.

### `PATCH /api/auth/me/`

- Supports direct profile fields above.
- Backward compatible with onboarding payload field `age`:
  - `age` is accepted and converted internally to `birth_date`.

## Dashboard and History

### `GET /api/dashboard/`

- Top-level keys: `summary`, `hydration`, `sleep`, `activity`, `gamification`.
- Nested minimum keys:
  - `summary`: `calories_target`, `calories_consumed`, `calories_remaining`, `calories_burned`, `burn_target`
  - `hydration`: `target`, `current`, `adjusted_target`
  - `sleep`: `target_bed_time`, `target_wake_time`, `recommended_sleep_hours`, `logged_hours_today`, `progress_percent`
  - `activity`: `steps`, `steps_target`, `distance_km`, `steps_burned`, `steps_burn_rate`
  - `gamification`: `points`, `level`

### `GET /api/history/`

- Top-level key: `history` (array).
- Per-item minimum keys:
  `date`, `water_current`, `water_target`, `steps`, `steps_target`, `distance_km`,
  `steps_burned`, `steps_burn_rate`, `calories_in`, `calories_target`,
  `calories_burned`, `sleep_hours`, `sleep_target`, `exercise_minutes`,
  `points_estimate`, `burn_target`, `burn_current`.

## Tracker Endpoints Used by Frontend

### `POST /api/water/`

- Minimum response keys: `id`, `amount_liter`, `date`.

### `POST /api/steps/`

- Minimum response keys: `id`, `steps_count`, `distance_km`, `date`,
  `calories_burned`, `burn_rate_kcal_per_km`.

### `POST /api/sleep/`

- Minimum response keys: `id`, `start_time`, `end_time`, `quality`, `date`,
  `duration_hours`, `points_earned`.

### `POST /api/activities/`

- Minimum response keys: `id`, `exercise`, `exercise_name`, `duration_minutes`,
  `date`, `calories_burned`.

### `POST /api/meals/`

- Minimum response keys: `id`, `food`, `food_name`, `meal_type`,
  `quantity_grams`, `date`, `total_calories`.

