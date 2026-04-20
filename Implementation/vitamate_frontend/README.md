# VitaMate Frontend

Flutter client for VitaMate health tracking. The app keeps `ChangeNotifier`
state management, consumes the Django API, and groups behavior by feature
modules under `lib/features`.

## Setup

1. Install Flutter stable.
2. From `Implementation/vitamate_frontend`, run `flutter pub get`.
3. Ensure the backend API base URL in the environment/config points to a live
   VitaMate backend.
4. Run the app with `flutter run`.

## Quality Gates

Run these commands before shipping changes:

```bash
flutter analyze
flutter test
```

## Architecture

- `lib/auth`: authentication screens, typed auth models, and auth state.
- `lib/core`: app-wide infrastructure such as networking, routing, theme, and
  notifications.
- `lib/features`: domain-specific modules. Each feature should prefer
  `data -> typed models -> controller -> screen/widgets`.
- `lib/shared`: reusable UI primitives shared across features.

Additional engineering rules live in
[`docs/architecture.md`](docs/architecture.md).

## Layer Boundaries

- Screens render UI and trigger controller actions. They should not parse raw
  API payloads or contain reusable business rules.
- Controllers own loading, submission, and UI-facing state. They should not
  depend on `BuildContext` for navigation or snackbars.
- Data/API classes translate network payloads and preserve public contract
  shapes.
- Notification and integration services stay in `core` or backend services, not
  in widget trees.

## Notes

- Chronic condition flows are intentionally data-driven; do not introduce one
  subclass per disease.
- Large UI files should be split once they pass roughly 400-500 lines into
  screen shell, section widgets, and forms/sheets.
