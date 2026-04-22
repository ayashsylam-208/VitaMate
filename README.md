# VitaMate

VitaMate is a mobile health and lifestyle tracking project built with a Django REST backend and a Flutter frontend.

## Academic Info
- University: Syrian Private University
- Faculty: Software Engineering
- Academic Year: 2025-2026
- Project Type: senior1 Project

## Team
- Salam Mohammed Al-Ayash
- Amenah Ayman Zaitoun

Supervisor: Dr. kadan jumaa ,Eng. Raghad Al-Hossny

## Repository Layout
- `Implementation/vitamate_backend`: Django backend
- `Implementation/vitamate_frontend`: Flutter frontend
- `.github/workflows/ci.yml`: GitHub Actions pipeline
- `.pre-commit-config.yaml`: local quality and secrets checks
- `.gitleaks.toml`: repository gitleaks rules
- `.gitleaksignore`: exact fingerprints ignored after manual review

## Frontend Engineering Notes
- The Flutter client keeps `ChangeNotifier`-based state management and groups behavior by feature modules under `Implementation/vitamate_frontend/lib/features`.
- Preferred frontend layering is `data -> typed models -> controller -> screen/widgets`.
- Screens should render UI and trigger controller actions; they should not parse raw API payloads or hold reusable business rules.
- Controllers own loading, submission, and UI-facing state; they should not depend on `BuildContext` for navigation or snackbars.
- Data and API classes translate backend payloads while preserving contract shapes.
- Notification and integration services should stay in `core` or backend services, not in widget trees.
- Chronic-condition flows are intentionally data-driven; do not introduce one subclass per disease.
- Large UI files should be split once they become hard to reason about, typically around 400-500 lines.
- The shared frontend architecture reference still lives in `Implementation/vitamate_frontend/docs/architecture.md`.

## Local Development

### Backend
```bash
cd Implementation/vitamate_backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### Frontend
```bash
cd Implementation/vitamate_frontend
flutter pub get
flutter run
```

## Local Quality Checks

### Backend tests
```bash
cd Implementation/vitamate_backend
python manage.py makemigrations --check --dry-run
python manage.py test users core gamification --verbosity 1
```

### Frontend checks
```bash
cd Implementation/vitamate_frontend
flutter analyze
flutter test
```

### Flutter integration tests
Playwright was replaced with Flutter `integration_test` because the client is a native Flutter application and the required E2E flow must exercise the real mobile UI layer, not a browser shell.

Prepare the backend and the reproducible E2E user:
```bash
cd Implementation/vitamate_backend
python manage.py migrate
python manage.py seed_integration_user --scenario chronic_flow --reset
python manage.py runserver 0.0.0.0:8000
```

Run the Flutter integration tests on an Android emulator:
```bash
cd Implementation/vitamate_frontend
flutter pub get
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/smoke_login_home_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/chronic_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The E2E seed command creates or resets:
- username: `e2e_chronic`
- password: `Pass123!`

The Flutter integration flow uses a real backend and validates the chronic-care path:
- login
- open `Conditions Center`
- add `Hypertension`
- add a follow-up reading
- verify the updated detail summary and the `Home` conditions section

Integration test operating notes:
- Run the smoke test first. It isolates login and home loading before the full chronic scenario.
- If the backend was already used by a previous run, rerun `seed_integration_user --scenario chronic_flow --reset` before executing the chronic flow again.
- CI uses the same `flutter drive` approach on an Android emulator.

### Medications flow notes
- The frontend uses one shared medication flow for both manual medications and condition-linked medications.
- The add/edit flow sends `source_type="manual"` for the Medications page.
- The chronic-condition detail path sends `source_type="condition"` together with `user_condition_id`.
- Reminder sync is backend-driven through `/api/medications/reminder-sync/`, then projected locally by `NotificationsService.syncMedicationReminders(...)`.
- Today dose rows and adherence state come from backend APIs such as `/api/medications/today/`; the UI should not calculate an independent medication state.

### iOS launch assets
- To customize the iOS launch screen, replace the assets under `Implementation/vitamate_frontend/ios/Runner/Assets.xcassets/LaunchImage.imageset`.

### Pre-commit with secrets scanning
Install `pre-commit` and make sure the `gitleaks` CLI is available on your `PATH`.

```bash
pip install pre-commit
pre-commit install
git add -A
pre-commit run --all-files --show-diff-on-failure
```

The local `pre-commit` flow includes:
- YAML validation
- JSON validation
- merge-conflict detection
- private-key detection
- staged secrets scanning with `gitleaks`

## CI Pipeline

The GitHub Actions workflow lives in [.github/workflows/ci.yml](/c:/Users/Salam%20Ayash/Desktop/VitaMate/.github/workflows/ci.yml) and is split into six explicit jobs:
- `gitleaks`: stages the repository snapshot and scans it for hardcoded secrets using `.gitleaks.toml` and `.gitleaksignore`
- `pre-commit`: runs repository-wide quality checks and the local gitleaks hook
- `backend-tests`: starts a PostgreSQL 17 service, runs `makemigrations --check --dry-run`, applies migrations, then runs Django tests
- `flutter-analyze`: runs `flutter analyze`
- `flutter-test`: runs `flutter test`
- `flutter-integration-test`: provisions PostgreSQL, migrates the backend, seeds the `e2e_chronic` user, starts Django, boots an Android emulator, then runs the Flutter smoke and chronic E2E suites against `http://10.0.2.2:8000`

## How To Read CI Results
- If `gitleaks` fails, there is a secrets leak or a false positive that must be handled in `.gitleaks.toml` or `.gitleaksignore`.
- If `pre-commit` fails, a local quality gate is failing and should be reproducible with `pre-commit run --all-files`.
- If `backend-tests` fails, inspect the Postgres-backed Django steps in this order: migration check, migrate, then test output.
- If `flutter-analyze` fails, there is a static-analysis issue in the Flutter app.
- If `flutter-test` fails, there is a unit or widget regression in the Flutter app.
- If `flutter-integration-test` fails, inspect the uploaded Django and Flutter logs first. The main failure categories are backend startup, seed setup, emulator boot, or a real E2E regression in the chronic flow.

## CI Database Contract
The backend CI job does not depend on any local database or machine-specific `.env` file. It receives these values directly from the workflow:
- `DJANGO_ENV=dev`
- `DJANGO_SECRET_KEY`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_HOST=127.0.0.1`
- `POSTGRES_PORT=5432`

This keeps the GitHub Actions environment reproducible and self-contained.
