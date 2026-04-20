# VitaMate

VitaMate is a mobile health and lifestyle tracking project built with a Django REST backend and a Flutter frontend.

## Academic Info
- University: Syrian Private University
- Faculty: Software Engineering
- Academic Year: 2025-2026
- Project Type: Junior Project

## Team
- Salam Mohammed Al-Ayash
- Amenah Ayman Zaitoun

Supervisor: Eng. Raghad Al-Hossny

## Repository Layout
- `Implementation/vitamate_backend`: Django backend
- `Implementation/vitamate_frontend`: Flutter frontend
- `.github/workflows/ci.yml`: GitHub Actions pipeline
- `.pre-commit-config.yaml`: local quality and secrets checks
- `.gitleaks.toml`: repository gitleaks rules
- `.gitleaksignore`: exact fingerprints ignored after manual review

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

The GitHub Actions workflow lives in [.github/workflows/ci.yml](/c:/Users/Salam%20Ayash/Desktop/VitaMate/.github/workflows/ci.yml) and is split into five explicit jobs:
- `gitleaks`: stages the repository snapshot and scans it for hardcoded secrets using `.gitleaks.toml` and `.gitleaksignore`
- `pre-commit`: runs repository-wide quality checks and the local gitleaks hook
- `backend-tests`: starts a PostgreSQL 17 service, runs `makemigrations --check --dry-run`, applies migrations, then runs Django tests
- `flutter-analyze`: runs `flutter analyze`
- `flutter-test`: runs `flutter test`

## How To Read CI Results
- If `gitleaks` fails, there is a secrets leak or a false positive that must be handled in `.gitleaks.toml` or `.gitleaksignore`.
- If `pre-commit` fails, a local quality gate is failing and should be reproducible with `pre-commit run --all-files`.
- If `backend-tests` fails, inspect the Postgres-backed Django steps in this order: migration check, migrate, then test output.
- If `flutter-analyze` fails, there is a static-analysis issue in the Flutter app.
- If `flutter-test` fails, there is a unit or widget regression in the Flutter app.

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
