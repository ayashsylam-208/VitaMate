# Health State Frontend Contract

Flutter must treat backend read models as the owner of tracker targets and medical status.

- Use `active_target` (or the unit-specific `active_target_ml`) for progress, remaining values, and completion.
- `base_target` and `adjusted_target` are explanatory fields only. Flutter must not choose between them.
- Use `state_version` and `generated_at`/`last_computed_at` to avoid replacing a newer state with an older response.
- Refresh the affected tracker summary after a successful write.
- Do not calculate chronic-condition classification, nutrient Low/Good/High status, or health constraints locally.
- Do not combine target data from one endpoint with progress from another state version.
- If a response explicitly reports health-state work as pending, show an updating state. A normal successful critical tracker write is expected to have a synchronously refreshed state.

The backend remains compatible with older response fields during migration, but `active_target` is authoritative.
