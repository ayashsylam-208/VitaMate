# VitaMate Chapter 6 Repository Audit

Audit scope: current working tree at S:\Projects\VitaMate\Implementation on 2026-08-05.

Important repository-state qualification: the working tree contains many modified and untracked files. In particular, .local/vitamate_ai_runtime, vitamate_backend/ai_meals, vitamate_backend/ai_service_runtime, notification_hub, manager, and several related Flutter modules are present locally but untracked. This audit therefore distinguishes current local implementation from committed Git history and CI coverage.

### Question 1
**Answer:**  
Python 3.10.0 is used by both local virtual environments. The active Flutter command reports Flutter 3.38.3 stable, Dart 3.10.1, and DevTools 2.51.1. The local PostgreSQL server is 17.9; SQL itself has no separate repository version.

**Evidence:**  
- vitamate_backend/.venv/pyvenv.cfg:1-3 - backend virtual environment records Python 3.10.0.
- .local/vitamate_ai_runtime/.venv/pyvenv.cfg:1-3 - AI virtual environment records Python 3.10.0.
- vitamate_frontend/pubspec.yaml:21-22 - Dart SDK constraint is ^3.10.1.
- vitamate_frontend/.metadata:6-8 - Flutter stable revision 19074d12f7eaf6a8180cd4036a430c1d76de904e.
- vitamate_backend/scripts/setup_postgres_portable.ps1:2-3 - portable PostgreSQL package is 17.9-3 for Windows x64.
- Runtime commands: flutter --version reported Flutter 3.38.3 and Dart 3.10.1; Django connection metadata reported PostgreSQL 17.9.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
VitaMate's verified local toolchain uses Python 3.10.0, Flutter 3.38.3, Dart 3.10.1, and PostgreSQL 17.9.

---

### Question 2
**Answer:**  
The Django dependency file pins Django 5.2.10, DRF 3.16.1, and SimpleJWT 5.5.1. Psycopg is constrained to >=3.2,<4 and Pillow to >=10.4,<13. The active installed AI environment reports FastAPI 0.135.3 and Uvicorn 0.44.0, while its generated lock records FastAPI 0.141.1 and Uvicorn 0.52.1; this is a reproducibility mismatch.

**Evidence:**  
- vitamate_backend/requirements.txt:1-9 - essential Django, DRF, SimpleJWT, Psycopg, Requests, and Pillow dependencies.
- .local/vitamate_ai_runtime/requirements-ai-runtime.lock.txt:40-40 - lock records FastAPI 0.141.1.
- .local/vitamate_ai_runtime/requirements-ai-runtime.lock.txt:219-219 - lock records Uvicorn 0.52.1.
- vitamate_backend/scripts/run_ai_service.ps1:43-48 - startup executes Uvicorn from the installed AI virtual environment.
- Runtime import command on the startup virtual environment reported FastAPI 0.135.3 and Uvicorn 0.44.0.

**Confidence:**  
Partially confirmed.

**Report-safe statement:**  
The Django stack is pinned to Django 5.2.10 and DRF 3.16.1, while the AI environment requires dependency-lock reconciliation before its FastAPI/Uvicorn versions are reported as reproducible.

---

### Question 3
**Answer:**  
Dio 5.9.0 is used for HTTP, flutter_secure_storage 9.2.4 for tokens, flutter_local_notifications 17.2.4 for local notifications, image_picker 1.2.3 for image selection, shared_preferences 2.5.4 for local preferences, pedometer 4.1.1 and permission_handler 11.4.0 for step sensing and permissions, and intl 0.19.0/timezone 0.9.4 for time handling. State management is implemented directly with ChangeNotifier controllers; no Provider, Riverpod, BLoC, or Get package is declared. No chart package is declared. Rive 0.13.20 is installed but no current lib source reference was found.

**Evidence:**  
- vitamate_frontend/pubspec.yaml:30-59 - direct Flutter dependencies and test SDK dependencies.
- vitamate_frontend/pubspec.lock:76-83 - Dio 5.9.0.
- vitamate_frontend/pubspec.lock:166-205 - local notifications 17.2.4 and secure storage 9.2.4.
- vitamate_frontend/pubspec.lock:285-292 - image_picker 1.2.3.
- vitamate_frontend/pubspec.lock:490-505 - pedometer 4.1.1 and permission_handler 11.4.0.
- vitamate_frontend/pubspec.lock:578-601 - Rive 0.13.20 and shared_preferences 2.5.4.
- vitamate_frontend/lib/core/notification_hub/services/local_plan_executor.dart:3-73 - active local-notification scheduling.
- vitamate_frontend/lib/features/activity/state/activity_controller.dart:4-40 - pedometer, permission handling, and ChangeNotifier controller.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The Flutter client uses Dio, secure storage, local notifications, image picking, and direct ChangeNotifier controllers without a third-party state-management or charting framework.

---

### Question 4
**Answer:**  
The installed AI runtime reports PyTorch 2.9.1+cpu, torchvision 0.24.1+cpu, Ultralytics 8.4.37, Transformers 5.5.4, OpenCV 4.11.0, NumPy 1.26.4, Pillow 11.3.0, Pydantic 2.13.0, and pandas 2.3.3. The generated lock contains different versions for several packages, including torch 2.13.0, torchvision 0.28.0, Ultralytics 8.4.115, OpenCV 5.0.0.93, and NumPy 2.2.6. Depth Anything V2 is bundled source and a local checkpoint rather than a separate pip dependency.

**Evidence:**  
- .local/vitamate_ai_runtime/requirements-ai-runtime.lock.txt:95-117 - locked NumPy, OpenCV, and pandas.
- .local/vitamate_ai_runtime/requirements-ai-runtime.lock.txt:177-191 - locked torch, torchvision, and Transformers.
- .local/vitamate_ai_runtime/requirements-ai-runtime.lock.txt:213-219 - locked Ultralytics and Uvicorn.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/depth/depth_anything_metric.py:50-90 - bundled Depth Anything V2 model.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/classification/siglip2_classifier.py:16-35 - local SigLIP2 recognition.
- Runtime import command on .local/vitamate_ai_runtime/.venv produced the installed versions listed above.

**Confidence:**  
Partially confirmed.

**Report-safe statement:**  
The meal-analysis runtime uses PyTorch, Ultralytics YOLO, Transformers/SigLIP2, OpenCV, NumPy, Pillow, and bundled Depth Anything V2, but its installed environment currently differs from its lock.

---

### Question 5
**Answer:**  
VS Code and Git are verified. An .idea directory exists, but that alone does not prove Android Studio or PyCharm usage. Docker is used only as a PostgreSQL service inside GitHub Actions; no application Dockerfile or Compose file exists. Postman, Insomnia, and database-administration tools are not verified.

**Evidence:**  
- vitamate_frontend/.vscode/launch.json:1-18 - VS Code Flutter launch configuration.
- vitamate_frontend/.vscode/tasks.json:1-16 - VS Code adb reverse task.
- ../.git/config:8-14 - Git remote and main branch configuration.
- ../.github/workflows/ci.yml:68-90 - CI PostgreSQL container service.
- Repository search found no Dockerfile, Compose, Postman, or Insomnia project file.

**Confidence:**  
Confirmed for VS Code and Git; not verified for the other tools.

**Report-safe statement:**  
Repository evidence confirms VS Code and Git usage, while Android Studio, PyCharm, Postman, and database GUI usage cannot be claimed.

---

### Question 6
**Answer:**  
Windows is the verified local environment through PowerShell scripts and Windows virtual-environment paths. Ubuntu is the verified GitHub Actions runner. An Android API 30 emulator is configured in CI. Real-device connection through adb reverse or LAN is documented, but actual physical-device test execution is not proven. Localhost execution is active. Docker is limited to the CI PostgreSQL service.

**Evidence:**  
- vitamate_backend/scripts/run_dev_server.ps1:28-96 - Windows PowerShell local backend/AI startup.
- vitamate_frontend/scripts/run_android_dev.ps1:83-117 - Android-device adb reverse and Flutter launch.
- ../.github/workflows/ci.yml:20-22 - Ubuntu runner.
- ../.github/workflows/ci.yml:267-278 - Android API 30 emulator.
- ../.github/workflows/ci.yml:76-90 - PostgreSQL 17 service container.

**Confidence:**  
Confirmed with the physical-device qualification above.

**Report-safe statement:**  
VitaMate is developed locally on Windows and validated in Ubuntu-based CI with an Android emulator; real-device connection is supported but repository-level execution evidence is absent.

---

### Question 7
**Answer:**  
Major current directories are:

    Implementation/
    |-- vitamate_backend/
    |   |-- vitamate_project/
    |   |-- users/
    |   |-- core/
    |   |-- gamification/
    |   |-- notification_hub/
    |   |-- manager/
    |   |-- ai_meals/
    |   |-- ai_service_runtime/
    |   |-- scripts/
    |   +-- docs/
    |-- vitamate_frontend/
    |   |-- lib/
    |   |-- test/
    |   |-- integration_test/
    |   |-- android/
    |   +-- scripts/
    |-- .local/vitamate_ai_runtime/
    |   |-- src/vitamate_ai_package/
    |   |-- models/
    |   |-- runs/
    |   +-- scripts/
    +-- ../.github/workflows/ci.yml

**Evidence:**  
- vitamate_backend/vitamate_project/settings_base.py:77-91 - active Django apps.
- vitamate_frontend/lib/app.dart:33-103 - active Flutter application and routes.
- vitamate_backend/scripts/run_ai_service.ps1:12-48 - local AI package and FastAPI wrapper boundary.
- ../.github/workflows/ci.yml:1-296 - CI configuration.

**Confidence:**  
Confirmed for the current local tree; several listed modules are untracked.

**Report-safe statement:**  
The current project is divided into a Flutter frontend, modular Django backend, local FastAPI AI runtime, tests, scripts, documentation, and GitHub Actions.

---

### Question 8
**Answer:**  
vitamate_project contains settings and root URLs. users handles authentication/profile data. core contains domain models, APIs, repositories, tracker services, constraints, chronic care, and health-state orchestration. gamification handles points and motivation. notification_hub owns device registration, preferences, plans, and reports. manager implements account management. ai_meals is the Django AI boundary, while ai_service_runtime secures the bundled FastAPI service.

**Evidence:**  
- vitamate_backend/vitamate_project/settings_base.py:77-91 - app registration.
- vitamate_backend/core/repositories/nutrition/meal_log_repository.py:1-34 - repository layer.
- vitamate_backend/core/services/orchestration/health_state_orchestrator.py:51-80 - orchestration entry.
- vitamate_backend/notification_hub/services/planner.py:29-64 - notification planner.
- vitamate_backend/ai_meals/services.py:152-374 - AI-session service.
- vitamate_backend/ai_service_runtime/secure_app.py:26-113 - secured FastAPI overlay.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The Django backend is organized by bounded feature modules with explicit API, service, repository, orchestration, notification, and AI-integration layers.

---

### Question 9
**Answer:**  
main.dart/bootstrap.dart initialize the app and global services, while app.dart declares routes. lib/core contains networking, auth, routing, storage, time, health synchronization, and Notification Hub infrastructure. lib/features contains feature-scoped models, data clients/repositories, ChangeNotifier controllers, screens, and widgets. Tests are under test and integration_test. State management is manual ChangeNotifier/listener composition.

**Evidence:**  
- vitamate_frontend/lib/app.dart:33-103 - application and route map.
- vitamate_frontend/lib/bootstrap.dart:1-87 - global initialization.
- vitamate_frontend/lib/auth/state/auth_controller.dart:14-40 - ChangeNotifier approach.
- vitamate_frontend/lib/features/nutrition/state/nutrition_controller.dart:24-60 - feature controller.
- vitamate_frontend/lib/core/notification_hub/state/notification_hub_controller.dart:20-54 - global notification controller.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The Flutter client uses a feature-first structure and direct ChangeNotifier controllers over shared core networking, storage, routing, and notification modules.

---

### Question 10
**Answer:**  
The VitaMate-owned FastAPI entry is ai_service_runtime/secure_app.py; it wraps the bundled package's FastAPI app. The vendor package implements pipeline orchestration, YOLO segmentation, semantic classification, depth estimation, deterministic weight estimation, nutrition estimation, image utilities, configuration, model manifests, readiness checks, and smoke testing. Training datasets and most training/evaluation scripts are intentionally excluded.

**Evidence:**  
- vitamate_backend/ai_service_runtime/secure_app.py:15-113 - secure startup, route protection, and queue control.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/api/app.py:34-112 - bundled FastAPI app and analyze route.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/pipeline/service.py:108-154 - component/model loading.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/segmentation/yolo_segmenter.py:24-59 - segmentation loading.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/utils/image_io.py:13-57 - preprocessing.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:3-18 - package boundary.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
VitaMate provides a secured FastAPI integration overlay around a bundled local package that owns the meal-image model pipeline and runtime assets.

---

### Question 11
**Answer:**  
Flutter/Dart implements the mobile UI, device services, and API client. Python/Django implements domain rules, persistence, orchestration, and account/tracker APIs. DRF exposes authenticated REST endpoints and serialization. FastAPI hosts local meal-image inference only. PostgreSQL is the principal relational database. SQLite is an opt-in development fallback. Android local-notification services execute plans synchronized from Django.

**Evidence:**  
- vitamate_frontend/lib/app.dart:33-103 - Flutter UI/routing responsibility.
- vitamate_backend/vitamate_project/settings_base.py:125-132 - DRF JWT authentication.
- vitamate_backend/vitamate_project/settings_base.py:57-72 - PostgreSQL configuration.
- vitamate_backend/vitamate_project/settings_dev.py:52-60 - opt-in SQLite fallback.
- vitamate_backend/ai_meals/gateway.py:14-77 - Django-to-FastAPI boundary.
- vitamate_frontend/lib/core/notification_hub/services/local_plan_executor.dart:14-73 - Android local execution.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Flutter provides the mobile client, Django/DRF owns application logic and persistence, FastAPI serves meal-image inference, PostgreSQL is primary storage, and Android schedules backend-defined notification plans locally.

---

### Question 12
**Answer:**  
PostgreSQL is principal; SQLite is used only when VITAMATE_USE_SQLITE=1 in development. Database variables are POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_HOST, and POSTGRES_PORT. Migrations are used locally and in CI. PostgreSQL 17.9 is verified locally. No production database deployment is verified.

**Evidence:**  
- vitamate_backend/vitamate_project/settings_base.py:57-72 - principal PostgreSQL settings.
- vitamate_backend/vitamate_project/settings_dev.py:52-60 - optional SQLite override.
- vitamate_backend/.env.example:8-13 - database environment variables.
- vitamate_backend/scripts/setup_postgres_portable.ps1:2-11 - local PostgreSQL 17.9 package and port.
- ../.github/workflows/ci.yml:115-122 - migrations and backend tests against PostgreSQL 17.
- Runtime Django query reported engine django.db.backends.postgresql, database vitamate_utf8, server 17.9.

**Confidence:**  
Confirmed except production deployment, which is not verified.

**Report-safe statement:**  
VitaMate uses PostgreSQL as its primary database, with SQLite available only as an explicit local-development fallback.

---

### Question 13
**Answer:**  
Active dependency files are requirements.txt for Django, pubspec.yaml/pubspec.lock for Flutter, requirements-ai-package.txt plus requirements-ai-runtime.lock.txt for the AI package, and requirements-overlay.in for secure integration additions. No pyproject.toml, poetry.lock, Pipfile, Dockerfile, or Compose file was found. The AI lock is present but does not match the currently installed AI environment.

**Evidence:**  
- vitamate_backend/requirements.txt:1-14 - Django/backend dependencies.
- vitamate_frontend/pubspec.yaml:19-59 - Flutter version, constraints, and direct dependencies.
- vitamate_frontend/pubspec.lock:1-782 - resolved Flutter dependency versions.
- .local/vitamate_ai_runtime/requirements-ai-package.txt:1-15 - bundled package dependency input.
- .local/vitamate_ai_runtime/requirements-ai-runtime.lock.txt:1-226 - generated AI lock.
- vitamate_backend/ai_service_runtime/requirements-overlay.in:1-4 - FastAPI/Uvicorn integration overlay.
- Repository search found none of pyproject.toml, poetry.lock, Pipfile, Dockerfile, or Compose.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Dependencies are managed through Python requirements files and Flutter pubspec files; no Poetry, Pipenv, or application Docker configuration is present.

---

### Question 14
**Answer:**  
DJANGO_ENV selects settings_dev or settings_prod. PostgreSQL, hosts, CORS, secrets, and AI integration are environment-driven. JWTAuthentication is configured globally through DRF, with default SimpleJWT behavior because no custom SIMPLE_JWT block is present. AI variables include AI_MEALS_BASE_URL, AI_MEALS_TIMEOUT_SECONDS, AI_MEALS_SERVICE_TOKEN, image limits, and AI_MEALS_SESSION_TTL_MINUTES. Notification preferences are persisted per user in NotificationPreferenceProfile. Secret values must not be reported.

**Evidence:**  
- vitamate_backend/vitamate_project/settings.py:10-18 - environment selection.
- vitamate_backend/vitamate_project/settings_base.py:57-72 - database configuration.
- vitamate_backend/vitamate_project/settings_base.py:125-146 - JWT and AI configuration.
- vitamate_backend/vitamate_project/settings_dev.py:6-40 - development secret, hosts, and CORS.
- vitamate_backend/vitamate_project/settings_prod.py:4-36 - required production settings and optional transport-security flags.
- vitamate_backend/.env.example:1-23 - environment variable names.
- vitamate_backend/notification_hub/models.py:67-95 - persisted notification preferences.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
VitaMate selects environment-specific Django settings and receives database, security, CORS, and AI-service configuration through environment variables, while notification preferences are stored per user.

---

### Question 15
**Answer:**  
Current local startup is script-based: run_dev_server.ps1 starts/checks AI and then executes Django runserver; run_ai_service.ps1 executes Uvicorn; run_android_dev.ps1 applies adb reverse and passes API base URLs to flutter run. setup_postgres_portable.ps1 installs/initializes local PostgreSQL. These scripts are current in the local working tree but untracked, so they are not yet reproducible from the committed repository.

**Evidence:**  
- vitamate_backend/scripts/run_dev_server.ps1:28-68 - AI startup/readiness handling.
- vitamate_backend/scripts/run_dev_server.ps1:78-96 - device addresses and Django runserver.
- vitamate_backend/scripts/run_ai_service.ps1:12-48 - AI environment, token validation, and Uvicorn.
- vitamate_frontend/scripts/run_android_dev.ps1:83-117 - adb reverse and Flutter.
- vitamate_backend/scripts/setup_postgres_portable.ps1:114-141 - PostgreSQL initialization/start.

**Confidence:**  
Confirmed for the local working tree; partially confirmed for repository reproducibility.

**Report-safe statement:**  
Local development uses PowerShell scripts to start PostgreSQL, the secured FastAPI runtime, Django, and Flutter with Android network forwarding.

---

### Question 16
**Answer:**  
The project uses Git with a GitHub origin. No GitLab remote is configured.

**Evidence:**  
- ../.git/config:8-13 - GitHub origin and main tracking.
- ../.github/workflows/ci.yml:1-12 - GitHub Actions workflow.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
VitaMate uses GitHub as its source-control and CI platform.

---

### Question 17
**Answer:**  
The default and only currently visible local/remote branch is main. No development branch, feature-branch naming convention, pull-request workflow, or documented branching strategy was found.

**Evidence:**  
- ../.git/HEAD:1-1 - HEAD references refs/heads/main.
- ../.git/config:11-14 - main tracks origin/main.
- Git branch inspection showed main and origin/main only.

**Confidence:**  
Partially confirmed.

**Report-safe statement:**  
The repository's default branch is main; a broader branching and pull-request strategy is not documented.

---

### Question 18
**Answer:**  
One GitHub Actions workflow runs on pushes and pull requests to main/master and manual dispatch. It performs Gitleaks scanning, pre-commit checks, Django tests with PostgreSQL 17, flutter analyze, flutter test, and Android emulator integration tests. It uploads integration logs. It contains no deployment job.

**Evidence:**  
- ../.github/workflows/ci.yml:3-17 - triggers and shared versions.
- ../.github/workflows/ci.yml:20-66 - Gitleaks and pre-commit jobs.
- ../.github/workflows/ci.yml:68-122 - PostgreSQL-backed Django job.
- ../.github/workflows/ci.yml:124-172 - Flutter analysis and tests.
- ../.github/workflows/ci.yml:174-296 - integration environment, emulator, and artifacts.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
GitHub Actions performs security checks, backend tests, Flutter analysis/tests, and Android emulator integration testing, but does not deploy the application.

---

### Question 19
**Answer:**  
Local execution and CI validation are verified. Production deployment, staging, application Docker deployment, published mobile release, app-store distribution, and a production HTTPS endpoint are not verified. Production settings are configuration capability, not deployment evidence.

**Evidence:**  
- vitamate_backend/scripts/run_dev_server.ps1:78-96 - local development server.
- vitamate_backend/vitamate_project/settings_prod.py:4-36 - production-capable settings only.
- ../.github/workflows/ci.yml:20-296 - test/analysis jobs and no deployment step.
- Repository search found no application Dockerfile or Compose file.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The repository verifies local and CI execution only; no production or staging deployment path is evidenced.

---

### Question 20
**Answer:**  
Backend tests use Django's TestCase, TransactionTestCase, SimpleTestCase, and DRF APITestCase. CI invokes python manage.py test users core gamification against PostgreSQL 17 after migrations. There is no separate test settings module or pytest configuration. Test helpers and seed commands are present, but no Factory Boy-style framework is declared. SQLite is not used by CI tests.

**Evidence:**  
- ../.github/workflows/ci.yml:68-122 - PostgreSQL service, migrations, seed, and Django test command.
- vitamate_backend/core/tests/constraints/test_constraints.py:7-29 - TestCase and TransactionTestCase patterns.
- vitamate_backend/core/tests/chronic/test_lipid_panel_mapping.py:3-10 - SimpleTestCase pattern.
- vitamate_backend/notification_hub/tests/test_notification_hub_api.py:1-40 - DRF API test pattern.
- vitamate_backend/requirements.txt:1-14 - no pytest or factory dependency.
- vitamate_backend/vitamate_project/settings_dev.py:52-60 - SQLite requires explicit opt-in.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Backend tests use Django/DRF test classes and run against PostgreSQL in CI, with no separate pytest or test-settings stack.

---

### Question 21
**Answer:**  
Flutter has unit/widget tests, nutrition golden tests, compact 360x800 golden coverage, and integration tests for login/home and chronic-condition flows. CI runs flutter test and uses an Android API 30 emulator for integration. The repository does not prove physical-device execution.

**Evidence:**  
- vitamate_frontend/test/features/nutrition/nutrition_golden_test.dart:30-132 - screen golden tests.
- vitamate_frontend/test/features/nutrition/nutrition_golden_test.dart:136-183 - compact 360x800 golden tests.
- vitamate_frontend/integration_test/smoke_login_home_test.dart:9-20 - integration binding and smoke flow.
- vitamate_frontend/integration_test/chronic_flow_test.dart:9-30 - chronic integration flow.
- ../.github/workflows/ci.yml:149-172 - flutter test command.
- ../.github/workflows/ci.yml:267-278 - API 30 emulator.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The Flutter test environment includes widget, golden, compact-viewport, and Android emulator integration tests.

---

### Question 22
**Answer:**  
The AI package includes readiness and single-image smoke scripts. Documentation mentions pytest and an egg-salad smoke script, but pytest is not installed in the active AI environment and the named script is absent. No packaged evaluation image set is available. Device selection is automatic; installed torch is CPU-only, and YOLO explicitly retries on CPU when Windows CUDA returns empty masks. The secure wrapper defaults to one concurrent analysis and a queue of two.

**Evidence:**  
- .local/vitamate_ai_runtime/scripts/check_ai_package_ready.py:49-156 - readiness checks.
- .local/vitamate_ai_runtime/scripts/smoke_test_ai_package.py:21-54 - one-image smoke entry.
- .local/vitamate_ai_runtime/FULL_PIPELINE_LOCAL_TESTING.md:49-57 - documented commands, including unavailable pytest/egg script.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:12-18 - test datasets and most evaluation assets excluded.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/utils/device.py:10-35 - hardware selection.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/segmentation/yolo_segmenter.py:94-143 - CPU default/retry.
- vitamate_backend/ai_service_runtime/secure_app.py:34-110 - concurrency, queue, and timeout controls.

**Confidence:**  
Partially confirmed.

**Report-safe statement:**  
AI runtime validation is limited to readiness and single-image smoke tooling, with CPU-safe inference and bounded local concurrency; a complete packaged evaluation suite is not present.

---

### Question 23
**Answer:**  
Report-ready active tree:

    VitaMate/
    |-- .github/workflows/ci.yml
    +-- Implementation/
        |-- vitamate_backend/
        |   |-- vitamate_project/       # settings and root URLs
        |   |-- users/                  # auth/profile
        |   |-- core/
        |   |   |-- api/                # tracker REST endpoints
        |   |   |-- models/             # health/domain data
        |   |   |-- repositories/       # selected data access
        |   |   +-- services/           # business/orchestration
        |   |-- gamification/           # points/motivation
        |   |-- notification_hub/       # plans/preferences/devices
        |   |-- manager/                # account manager
        |   |-- ai_meals/               # Django AI sessions/gateway
        |   |-- ai_service_runtime/      # secure FastAPI overlay
        |   |-- scripts/
        |   |-- docs/
        |   +-- requirements.txt
        |-- vitamate_frontend/
        |   |-- lib/
        |   |   |-- auth/
        |   |   |-- core/
        |   |   |-- features/
        |   |   +-- shared/
        |   |-- test/
        |   |-- integration_test/
        |   |-- android/
        |   |-- scripts/
        |   |-- pubspec.yaml
        |   +-- pubspec.lock
        +-- .local/vitamate_ai_runtime/
            |-- src/vitamate_ai_package/
            |-- models/
            |-- runs/
            |-- scripts/
            +-- docs/

**Evidence:**  
- vitamate_backend/vitamate_project/settings_base.py:77-91 - active backend apps.
- vitamate_frontend/lib/app.dart:33-103 - active frontend.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:3-18 - AI package boundary.

**Confidence:**  
Confirmed for the current local tree.

**Report-safe statement:**  
The active project tree separates mobile presentation, backend domain services, notification planning, and local meal-image inference.

---

### Question 24
**Answer:**  
Representative backend map:

| Domain | Primary service | API/view | Primary models | Responsibility |
|---|---|---|---|---|
| Auth/profile | UserProfileService | RegisterView, ManageUserView | User, UserProfile | Registration and profile mutation |
| Nutrition | NutritionLoggingService, MealFinalizationService | MealLogViewSet | FoodItem, NutritionFacts, MealLog, MealLogComponent | Canonical food logging and nutrient snapshots |
| Hydration | WaterLoggingService | WaterLogViewSet | WaterLog | Water target/log lifecycle |
| Activity/steps | ActivityService, StepsService, ActivitySessionService | ActivityLogViewSet, StepLogViewSet, session views | ActivityLog, StepLog, ActivitySession | Manual/sensor activity and sessions |
| Sleep | SleepLoggingService | SleepLogViewSet | SleepLog | Sleep logging and summary |
| Medication | MedicationDoseWorkflowService, MedicationPlanService | MedicationViewSet | ConditionMedication, Schedule, Log | Medication plan and dose actions |
| Chronic conditions | ChronicConditionService, ConditionSetupService, ConditionMeasurementWorkflowService | chronic views | UserCondition, HealthIndicatorRecord, ConditionAlert | Setup, readings, rules, alerts |
| Goals/habits | UnhealthyHabitService | habits API views | UnhealthyHabit, Plan, Log | Habit plan/log/progress |
| Motivation | PointsService, MotivationService | motivation system views | UserScore, PointsTransaction, DailyMission, Badge | Points and motivation feed |
| Constraints | ConstraintResolutionService | constraints views | materialized constraints | Resolve effective health targets |
| Health coordination | HealthStateOrchestrator, HealthTrackerCoordinator | read-model views | UnifiedHealthState | Recompute and dashboard read model |

**Evidence:**  
- vitamate_backend/users/services/user_profile_service.py:9-107 - profile service.
- vitamate_backend/users/views.py:7-26 - registration/profile views.
- vitamate_backend/users/models.py:9-84 - profile model.
- vitamate_backend/core/services/nutrition/nutrition_service.py:108-227 - nutrition service.
- vitamate_backend/core/api/nutrition/views.py:25-100 - nutrition API.
- vitamate_backend/core/models/nutrition.py:32-730 - nutrition and hydration models.
- vitamate_backend/core/services/hydration/water_service.py:17-180 - hydration service.
- vitamate_backend/core/api/hydration/views.py:12-96 - hydration API.
- vitamate_backend/core/services/tracking/activity_service.py:8-100 - activity service.
- vitamate_backend/core/services/tracking/steps_service.py:13-167 - steps service.
- vitamate_backend/core/services/tracking/activity_session_service.py:17-220 - activity-session service.
- vitamate_backend/core/api/tracking/views.py:28-297 - activity, steps, and sleep APIs.
- vitamate_backend/core/services/medication/medication_dose_workflow_service.py:18-220 - dose workflow.
- vitamate_backend/core/api/medication/views.py:30-200 - medication API.
- vitamate_backend/core/models/chronic.py:9-619 - chronic and medication models.
- vitamate_backend/core/services/chronic/chronic_condition_service.py:51-220 - chronic-condition service.
- vitamate_backend/core/services/chronic/condition_setup_service.py:23-180 - condition setup.
- vitamate_backend/core/services/habits/unhealthy_habit_service.py:31-240 - habit service.
- vitamate_backend/core/models/unhealthy_habits.py:7-227 - habit models.
- vitamate_backend/gamification/services/points_service.py:15-200 - points service.
- vitamate_backend/gamification/services/motivation_service.py:70-220 - motivation service.
- vitamate_backend/gamification/models.py:7-330 - gamification models.
- vitamate_backend/core/services/constraints/constraint_resolution_service.py:21-102 - constraint service.
- vitamate_backend/core/api/constraints/views.py:14-77 - constraint API.
- vitamate_backend/core/services/orchestration/health_state_orchestrator.py:51-214 - health-state orchestration.
- vitamate_backend/core/services/tracking/health_tracker_coordinator.py:15-122 - coordinator/read facade.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
VitaMate implements tracker logic through domain-specific Django services and APIs coordinated by materialized health-state and constraint services.

---

### Question 25
**Answer:**  
Three representative data-access examples are available.

**Evidence:**  
- vitamate_backend/core/repositories/nutrition/meal_log_repository.py:17-34 - owner/date-scoped repository query:

      MealLog.objects.filter(user=user, date=log_date)
          .select_related("food", "serving_option")
          .prefetch_related("components__food_item")

- vitamate_backend/ai_meals/services.py:398-406 - owner-scoped row lock:

      MealAnalysisSession.objects.select_for_update().get(
          id=analysis_id,
          user=user,
      )

- vitamate_backend/core/services/nutrition/meal_finalization_service.py:28-65 - atomic duplicate-safe finalization:

      @transaction.atomic
      def finalize(...):
          get_user_model().objects.select_for_update().only("id").get(id=user.id)
          existing = MealLog.objects.filter(
              user=user, finalization_key=finalization_key
          ).first()

**Confidence:**  
Confirmed.

**Report-safe statement:**  
VitaMate uses owner-scoped ORM queries, selected repository classes, and atomic row locking for sensitive finalization workflows.

---

### Question 26
**Answer:**  
Meal finalization is the representative business-logic example.

**Evidence:**  
- vitamate_backend/core/services/nutrition/meal_finalization_service.py:51-65:

      if not components:
          raise ValidationError({"components": "At least one component is required."})
      if finalization_key:
          get_user_model().objects.select_for_update().only("id").get(id=user.id)
          existing = MealLog.objects.filter(
              user=user,
              finalization_key=finalization_key,
          ).first()
          if existing is not None:
              return existing
      resolved = [cls._resolve_component(user=user, value=value) for value in components]

The input is a user, meal metadata, canonical component selections, and an optional idempotency key. The method validates components, serializes same-user finalization through a row lock, returns an existing meal for duplicate keys, and resolves each confirmed component. It then creates nutrient snapshots and one meal record. The output is the finalized MealLog.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Meal finalization validates canonical components and uses transaction locking plus an idempotency key to prevent duplicate meal creation.

---

### Question 27
**Answer:**  
Main Flutter implementation files are listed below.

**Evidence:**  
- vitamate_frontend/lib/auth/screens/login_screen.dart:37-400 - login UI.
- vitamate_frontend/lib/auth/screens/signup_screen.dart:39-500 - signup UI.
- vitamate_frontend/lib/auth/state/auth_controller.dart:14-158 - authentication state.
- vitamate_frontend/lib/features/home/screens/home_screen.dart:24-800 - home UI.
- vitamate_frontend/lib/features/home/state/home_controller.dart:9-80 - home state.
- vitamate_frontend/lib/features/nutrition/screens/nutrition_dashboard_screen.dart:20-900 - nutrition UI.
- vitamate_frontend/lib/features/nutrition/state/nutrition_controller.dart:24-500 - nutrition state.
- vitamate_frontend/lib/features/nutrition/state/ai_meal_controller.dart:20-300 - AI meal state.
- vitamate_frontend/lib/features/water/screens/water_screen.dart:6-24 - hydration UI.
- vitamate_frontend/lib/features/water/state/water_controller.dart:21-420 - hydration state.
- vitamate_frontend/lib/features/activity/screens/activity_screen.dart:28-2200 - activity UI.
- vitamate_frontend/lib/features/activity/state/activity_controller.dart:40-800 - activity and sensor state.
- vitamate_frontend/lib/features/sleep/screens/sleep_screen.dart:18-700 - sleep UI.
- vitamate_frontend/lib/features/sleep/state/sleep_coach_controller.dart:8-146 - sleep state.
- vitamate_frontend/lib/features/medications/screens/medications_screen.dart:23-900 - medication UI.
- vitamate_frontend/lib/features/medications/state/medications_controller.dart:13-367 - medication state.
- vitamate_frontend/lib/features/chronic_conditions/screens/chronic_conditions_screen.dart:16-292 - chronic-condition UI.
- vitamate_frontend/lib/features/chronic_conditions/state/chronic_conditions_controller.dart:11-500 - chronic-condition state.
- vitamate_frontend/lib/features/motivation/screens/motivation_screen.dart:11-500 - motivation UI.
- vitamate_frontend/lib/features/motivation/state/motivation_controller.dart:8-141 - motivation state.
- vitamate_frontend/lib/core/notification_hub/state/notification_hub_controller.dart:20-210 - notification state.
- vitamate_frontend/lib/core/notification_hub/services/local_plan_executor.dart:10-160 - local scheduling.
- vitamate_frontend/lib/features/manager/screens/my_vitamate_screen.dart:19-336 - manager/profile UI.
- vitamate_frontend/lib/features/manager/state/manager_overview_controller.dart:7-39 - manager/profile state.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Each major Flutter feature has dedicated screens and ChangeNotifier controllers, with shared notification and networking services under lib/core.

---

### Question 28
**Answer:**  
Recommended active screenshots are Home, Nutrition Dashboard, Activity, Progress, Medications, Habits, Chronic Conditions, and My VitaMate. These are present in the route map; the separate MotivationScreen exists but is not the main named score route in app.dart.

**Evidence:**  
- vitamate_frontend/lib/app.dart:43-82 - active named route map.
- vitamate_frontend/lib/features/home/screens/home_screen.dart:24-40 - Home.
- vitamate_frontend/lib/features/nutrition/screens/nutrition_dashboard_screen.dart:20-40 - Nutrition.
- vitamate_frontend/lib/features/activity/screens/activity_screen.dart:28-45 - Activity.
- vitamate_frontend/lib/features/stats/screens/stats_screen.dart:15-35 - Progress.
- vitamate_frontend/lib/features/medications/screens/medications_screen.dart:23-40 - Medications.
- vitamate_frontend/lib/features/habits/screens/habits_screen.dart:1-35 - Habits.
- vitamate_frontend/lib/features/chronic_conditions/screens/chronic_conditions_screen.dart:16-35 - Chronic Conditions.
- vitamate_frontend/lib/features/manager/screens/my_vitamate_screen.dart:19-40 - My VitaMate.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Eight route-backed screens can document the implemented mobile UI without relying on inactive mockups.

---

### Question 29
**Answer:**  
Representative endpoint: POST /api/nutrition/ai-meals/analyze/. AnalyzeMealView uses AnalyzeMealSerializer, calls MealAnalysisService.analyze, requires JWT-authenticated IsAuthenticated access, and returns 201 on success. Important errors are 400 for request validation, 422 for analysis rejection, and 503 when the AI runtime is unavailable.

**Evidence:**  
- vitamate_backend/vitamate_project/urls.py:118-118 - ai_meals mounted under /api/nutrition/ai-meals/.
- vitamate_backend/ai_meals/urls.py:10-22 - analyze, confirmation, and finalize paths.
- vitamate_backend/ai_meals/views.py:22-62 - authentication, multipart parsing, validation, delegation, and statuses.
- vitamate_backend/ai_meals/serializers.py:12-20 - upload fields.
- vitamate_backend/ai_meals/services.py:152-236 - analyze service.

Representative excerpt from vitamate_backend/ai_meals/views.py:27-43:

    serializer = AnalyzeMealSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    try:
        analysis = service.analyze(
            user=request.user,
            uploaded_file=serializer.validated_data["image"],
            analysis_key=analysis_key,
        )
    except AIAnalysisError as exc:
        ...

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The authenticated AI-meal upload endpoint validates multipart input, delegates analysis to a service, and maps domain/runtime failures to explicit HTTP statuses.

---

### Question 30
**Answer:**  
The backend registers devices, stores per-user preferences, compiles 72-hour plans, applies quiet-hour and motivation policies, and returns plans/cancellations/in-app events through sync. Flutter registers and synchronizes, presents foreground events, reconciles local Android schedules, routes opens, and reports scheduling/open/cancel events to Django. Django does not directly push these notifications in v1.

**Evidence:**  
- vitamate_backend/notification_hub/models.py:14-235 - devices, preferences, plans, and events.
- vitamate_backend/notification_hub/urls.py:11-15 - register/preferences/sync/report.
- vitamate_backend/notification_hub/services/planner.py:29-112 - horizon, quiet hours, suppression, quotas.
- vitamate_backend/notification_hub/services/planner.py:115-127 - domain compilers.
- vitamate_backend/notification_hub/services/planner.py:229-359 - sync and event reporting.
- vitamate_frontend/lib/core/notification_hub/state/notification_hub_controller.dart:96-188 - register/sync/reconcile/report.
- vitamate_frontend/lib/core/notification_hub/services/local_plan_executor.dart:14-158 - Android schedule and cancel.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Django owns notification planning and policy, while Flutter synchronizes each plan and schedules it locally on Android before reporting execution events.

---

### Question 31
**Answer:**  
ConstraintResolutionService collects candidates, validates them, resolves conflicts, and materializes effective constraints. EffectiveConstraintReader is the authoritative tracker-target facade. Domain mutations publish events after transaction commit; HealthStateOrchestrator recomputes only impacted domains and materializes UnifiedHealthState. HealthTrackerCoordinator and ReadModelService convert materialized state into dashboard/history/tracker payloads.

**Evidence:**  
- vitamate_backend/core/api/constraints/views.py:14-77 - constraint entry points.
- vitamate_backend/core/services/constraints/constraint_resolution_service.py:21-102 - collect/validate/resolve/materialize.
- vitamate_backend/core/services/constraints/effective_constraint_reader.py:30-169 - effective-target reader.
- vitamate_backend/core/services/orchestration/health_state_event_publisher.py:11-37 - transaction.on_commit publication.
- vitamate_backend/core/services/orchestration/health_state_orchestrator.py:51-214 - impacted-domain recomputation.
- vitamate_backend/core/services/tracking/health_tracker_coordinator.py:15-122 - dashboard/history facade.
- vitamate_backend/core/services/orchestration/read_model_service.py:75-205 - home/progress read models.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Health constraints and tracker coordination are deterministic Django services that materialize a unified read model for dashboards and tracker views.

---

### Question 32
**Answer:**  
VitaMate-owned code includes the Django ai_meals app, secure FastAPI overlay, setup/run scripts, canonical nutrition integration, and Flutter AI screens/client. The bundled runtime under .local/vitamate_ai_runtime owns model loading and inference internals. Model paths, thresholds, device, catalogs, and protocol settings are configurable. Training source datasets and most training/evaluation scripts are excluded, so complete provenance and procedure are not verifiable.

**Evidence:**  
- vitamate_backend/ai_meals/gateway.py:14-77 - VitaMate service boundary.
- vitamate_backend/ai_service_runtime/secure_app.py:15-147 - VitaMate security/operations overlay.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/pipeline/service.py:108-154 - bundled runtime internals.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/config.py:30-115 - configurable settings.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:3-18 - included/excluded boundary.
- Git status inspection: both the AI package and integration apps are currently untracked.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
VitaMate integrates a bundled local inference package through owned Django and FastAPI security layers, while full training assets are outside the accessible package.

---

### Question 33
**Answer:**  
Food segmentation uses binary YOLO-seg through Ultralytics with seed17_final_phase1_human_masks.pt as primary and foodv1_finetune_quality.pt as rescue. Dish recognition uses a fine-tuned SigLIP vision head backed by local google/siglip2-base-patch16-256 weights and best_dish_classifier.pt. Ingredient recognition has no fine-tuned checkpoint and falls back to local SigLIP2 zero-shot/catalog evidence. Depth uses Depth Anything V2 metric depth, ViT-L encoder, Hypersim checkpoint. Geometry/weight uses deterministic plate/depth volume integration and density rules, but the secure current route forces automatic weight to skip.

**Evidence:**  
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:2-10 - YOLO-seg task and active checkpoint.
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:37-49 - rescue and legacy-reference roles.
- .local/vitamate_ai_runtime/models/semantics/active_models.json:2-5 - active dish checkpoint.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/classification/finetuned_classifier.py:18-65 - fine-tuned SigLIP loader.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/classification/siglip2_classifier.py:16-87 - zero-shot local SigLIP2.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/config.py:82-100 - SigLIP2 and Depth Anything.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/depth/depth_anything_metric.py:65-98 - depth loading.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/weight/estimator.py:353-398 - volume/weight calculation.
- vitamate_backend/ai_service_runtime/secure_app.py:45-53 - active skip override.

**Confidence:**  
Confirmed for accessible models and current local assets.

**Report-safe statement:**  
The accessible runtime combines binary YOLO-seg, a fine-tuned SigLIP2 dish head, zero-shot/catalog ingredient evidence, and an optional Depth Anything V2 weight path disabled in the current integration.

---

### Question 34
**Answer:**  
Present active assets are seed17_final_phase1_human_masks.pt (primary staging-approved segmentation), foodv1_finetune_quality.pt (rescue only), best_dish_classifier.pt (accepted dish-only runtime staging), local SigLIP2 model.safetensors (backbone/fallback), and depth_anything_v2_metric_hypersim_vitl.pth (optional depth). The ingredient fine-tuned checkpoint is configured but absent. baseline_food_seg_subset.pt is reference-only and absent. Runtime model names are returned in model_versions and persisted in MealAnalysisSession.model_versions.

**Evidence:**  
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:5-10 - primary metadata and SHA-256.
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:37-49 - rescue/reference metadata.
- .local/vitamate_ai_runtime/models/semantics/active_models.json:2-5 - dish status.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/config.py:82-100 - semantic/depth paths.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/pipeline/service.py:1356-1401 - model_versions.
- vitamate_backend/ai_meals/models.py:56-60 - persisted model versions and estimated weight.
- File-existence audit confirmed primary, rescue, dish, SigLIP2, and depth files; ingredient and legacy-reference paths were absent.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Active runtime assets and their roles are versioned through manifests and session metadata; absent or reference-only checkpoints must not be called active or final.

---

### Question 35
**Answer:**  
The semantic dish artifact records 355 training rows and 56 evaluation rows with label/class counts and seed 17, but references an external Windows manifest path; images, license, source, and annotations are not packaged. The segmentation manifest claims VitaMate human-mask fine-tuning and an independent test split, but image counts, source, license, and split files are absent. Runtime assets contain 20 curated dishes, 88 ingredients, 40 bundled nutrition items, 50 default dishes, and a 46-row nutrition CSV. Django's canonical seed contains 250 foods; live local PostgreSQL currently contains 962 FoodItem and NutritionFacts rows, 1,030 aliases, 30 nutrients, 6,392 item-nutrient values, and 1,424 serving options.

**Evidence:**  
- .local/vitamate_ai_runtime/runs/semantic_finetune/dish_classifier_vitamate_mapping/model_manifest.json:2-11 - external paths and split counts.
- .local/vitamate_ai_runtime/runs/semantic_finetune/dish_classifier_vitamate_mapping/model_manifest.json:12-77 - labels, class counts, seed, checkpoint.
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:5-10 - segmentation fine-tuning claim.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:12-18 - datasets and masks excluded.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/config.py:103-115 - runtime catalog locations.
- vitamate_backend/core/data/nutrition_seed_250.json:1-20 - canonical seed structure.
- Read-only count commands produced the catalog and PostgreSQL counts above.

**Confidence:**  
Partially confirmed.

**Report-safe statement:**  
Runtime catalogs and limited split metadata are available, but complete training dataset provenance, annotations, and licensing are not present.

---

### Question 36
**Answer:**  
The repository proves pretrained inference plus fine-tuning artifacts, not training from scratch. The dish artifact records two head-only epochs and six last-vision-layer epochs. The segmentation manifest records selected baseline/candidate roles and a fine-tuned primary, but training scripts/configuration are excluded. Batch size, optimizer, learning rate, augmentation, and training hardware are not verified. The original dish run directory is external.

**Evidence:**  
- .local/vitamate_ai_runtime/runs/semantic_finetune/dish_classifier_vitamate_mapping/training_summary.json:86-191 - epoch history.
- .local/vitamate_ai_runtime/runs/semantic_finetune/dish_classifier_vitamate_mapping/model_manifest.json:2-11 - external path and preprocessing.
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:5-34 - fine-tuned primary and candidates.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:12-18 - training/evaluation assets excluded.

**Confidence:**  
Partially confirmed.

**Report-safe statement:**  
VitaMate has fine-tuned model artifacts and limited epoch history, but the accessible repository lacks a complete reproducible training configuration and does not prove training from scratch.

---

### Question 37
**Answer:**  
Django validates content type, bytes, decoded image, dimensions, and pixel count; applies EXIF orientation; composites alpha onto white; converts modes to RGB; and emits normalized JPEG bytes. The runtime decodes to PIL RGB, converts to NumPy RGB, optionally converts RGB to BGR for OpenCV, and resizes the maximum side with LANCZOS. Tensor normalization/conversion is owned by Ultralytics, Transformers AutoProcessor, and Depth Anything. Segmentation masks are thresholded, optionally plate-clipped, and small connected components are removed.

**Evidence:**  
- vitamate_backend/ai_meals/services.py:37-104 - Django validation and normalization.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/utils/image_io.py:13-57 - decode, RGB, NumPy/BGR, resize.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/classification/finetuned_classifier.py:42-65 - model processor loading.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/segmentation/yolo_segmenter.py:282-343 - mask processing.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Images are validated and normalized in Django, then converted and resized by the local runtime before model-specific tensor processing and mask cleanup.

---

### Question 38
**Answer:**  
The active sequence is Flutter upload -> Django validation/session creation -> authenticated service-to-service POST to FastAPI -> FastAPI provisional segmentation/recognition response -> Django session/component persistence -> user review/edit in Flutter -> canonical FoodItem mapping and confirmed grams -> Django MealFinalizationService creates the final meal and nutrient snapshot.

**Evidence:**  
- vitamate_frontend/lib/features/nutrition/data/ai_meal_api.dart:8-90 - Flutter analyze/confirmation/finalize calls to Django.
- vitamate_backend/ai_meals/views.py:22-62 - Django upload API.
- vitamate_backend/ai_meals/services.py:37-104 - validation.
- vitamate_backend/ai_meals/gateway.py:14-77 - service-to-service request.
- vitamate_backend/ai_service_runtime/secure_app.py:56-110 - protected FastAPI analysis.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/pipeline/service.py:964-1450 - provisional pipeline.
- vitamate_backend/ai_meals/services.py:238-308 - confirmation/catalog mapping.
- vitamate_backend/ai_meals/services.py:310-374 - finalization.
- vitamate_backend/core/services/nutrition/meal_finalization_service.py:28-168 - canonical meal creation.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Flutter never calls FastAPI directly; Django validates and persists provisional AI output, then finalizes only user-confirmed canonical food components.

---

### Question 39
**Answer:**  
Segmentation produces one binary food-region mask, not ingredient-instance masks. It unions valid YOLO masks, clips to plate geometry when safe, removes tiny blobs, calculates confidence/coverage, and may invoke rescue or heuristic fallback. Dish candidates use the fine-tuned SigLIP head plus catalog logic; ingredient candidates use SigLIP2/catalog evidence because the ingredient checkpoint is absent. Labels are normalized through closed-set vocabularies and aliases. In the active secure flow, automatic depth/volume/weight is disabled; Django requires user-confirmed grams for every mapped component. The optional estimator integrates positive depth over pixel area, applies shape factor and density, and returns grams.

**Evidence:**  
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:58-60 - binary food-region scope.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/segmentation/yolo_segmenter.py:282-343 - mask cleanup.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/segmentation/yolo_segmenter.py:367-475 - primary/rescue logic.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/pipeline/service.py:280-356 - semantic candidates.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/config.py:103-115 - label/alias catalogs.
- vitamate_backend/ai_service_runtime/secure_app.py:45-53 - automatic weight skipped.
- vitamate_backend/ai_meals/services.py:425-489 - optional estimated weight/suggested grams.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/weight/estimator.py:353-398 - optional calculation.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The current integration uses binary food-region segmentation and provisional semantic candidates, while final component quantities remain user-confirmed because automatic depth-based weight estimation is disabled.

---

### Question 40
**Answer:**  
Final nutrition is calculated from Django's canonical FoodItem, NutritionFacts, Nutrient, ItemNutrientValue, and NutritionServingOption tables. Aliases and AI mappings resolve candidates to canonical items. Facts use per-100 g or per-100 ml bases; confirmed grams/servings become a scale factor. Macro and micronutrient values are copied into immutable MealLog and MealLogComponent snapshots used by daily totals. Raw AI nutrition remains provisional and is not directly trusted.

**Evidence:**  
- vitamate_backend/core/models/nutrition.py:32-148 - canonical FoodItem and aliases.
- vitamate_backend/core/models/nutrition.py:234-426 - facts, nutrients, values, and servings.
- vitamate_backend/core/models/nutrition.py:451-617 - meal/component snapshots.
- vitamate_backend/core/services/nutrition/nutrition_service.py:765-890 - amount resolution and scaling.
- vitamate_backend/core/services/nutrition/meal_finalization_service.py:202-259 - canonical mapping/confirmation.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/pipeline/service.py:1210-1246 - AI nutrition marked provisional.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Final meal nutrients are recomputed from VitaMate's canonical Django nutrition catalog and confirmed quantities rather than accepted from raw AI output.

---

### Question 41
**Answer:**  
Django exposes analyze, confirmation PATCH, and finalize endpoints. FastAPI exposes /analyze and /finalize internally, but the active Django gateway calls only /analyze; final meal nutrition is finalized in Django. A service token protects FastAPI. Analyze accepts an image and idempotency key; the secure wrapper forces auto_weight_mode=skip. Session statuses are uploaded, analyzing, review, needs_input, ready_to_finalize, failed, finalized, and expired. TTL defaults to 30 minutes. Confirmation requires canonical food_item_id and confirmed_grams. Finalization locks user/session and uses a finalization key plus database uniqueness.

**Evidence:**  
- vitamate_backend/ai_meals/urls.py:10-22 - Django AI routes.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/api/app.py:83-134 - internal routes.
- vitamate_backend/ai_meals/gateway.py:35-40 - Django calls only /analyze.
- vitamate_backend/ai_service_runtime/secure_app.py:26-32,56-67 - service token.
- vitamate_backend/ai_meals/models.py:16-32,43-94 - statuses, key, versions, expiry, uniqueness.
- vitamate_backend/vitamate_project/settings_base.py:139-146 - URL, timeout, TTL, limits.
- vitamate_backend/ai_meals/serializers.py:138-156 - confirmation fields.
- vitamate_backend/ai_meals/services.py:238-374 - review and finalization.
- vitamate_backend/core/models/nutrition.py:548-569 - finalization uniqueness.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
AI meals use persisted, expiring Django sessions with authenticated analysis, user PATCH confirmation, and idempotent canonical finalization.

---

### Question 42
**Answer:**  
Django enforces accepted image types, byte size, minimum/maximum dimensions, and pixels. The gateway has a configurable timeout. FastAPI enforces token authentication, request size, one concurrent analysis by default, queue size two, and queue timeout. Unsupported or low-confidence results remain provisional and request user input. Expired/failed sessions are blocked. Runtime unavailability maps to 503. Flutter offers retake and manual food-library entry. Duplicate analysis and finalization are guarded by idempotency keys.

**Evidence:**  
- vitamate_backend/ai_meals/services.py:37-104 - upload controls.
- vitamate_backend/vitamate_project/settings_base.py:139-146 - timeout and limits.
- vitamate_backend/ai_meals/gateway.py:35-64 - timeout/unavailable mapping.
- vitamate_backend/ai_service_runtime/secure_app.py:34-110 - concurrency, queue, auth, size.
- .local/vitamate_ai_runtime/src/vitamate_ai_package/pipeline/service.py:229-257,639-754 - low-confidence/unsupported handling.
- vitamate_backend/ai_meals/services.py:389-415 - expired/failed safeguards.
- vitamate_backend/ai_meals/views.py:42-55 - 422/503 mapping.
- vitamate_frontend/lib/features/nutrition/screens/log_meal_screen.dart:57-79,250-285 - manual/photo alternatives.
- vitamate_frontend/lib/features/nutrition/screens/ai_meal_review_screen.dart:230-250 - retake flow.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
The AI path is bounded by upload validation, timeouts, queue limits, provisional low-confidence handling, session expiry, and manual-entry fallback.

---

### Question 43
**Answer:**  
Representative AI integration excerpt: Django-to-FastAPI gateway.

**Evidence:**  
- vitamate_backend/ai_meals/gateway.py:29-43:

      response = requests.post(
          f"{settings.AI_MEALS_BASE_URL}/analyze",
          files={"image": (image_name, image_bytes, content_type)},
          data={"auto_weight_mode": auto_weight_mode},
          headers={"X-VitaMate-Service-Token": settings.AI_MEALS_SERVICE_TOKEN},
          timeout=settings.AI_MEALS_TIMEOUT_SECONDS,
      )

This shows that model inference remains an internal authenticated service call, includes the normalized image and weight mode, and is bounded by a configured timeout. It does not expose vendor model internals.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Django invokes the local inference service through a token-authenticated multipart request with an explicit timeout.

---

### Question 44
**Answer:**  
The Senior Project 1 implementation baseline cannot be identified reliably. No SP1 tag, branch, release, document, or commit marker was found, and current major additions are untracked. Current-code existence or migration numbering is insufficient to assign features to SP1.

**Evidence:**  
- ../.git/HEAD:1-1 - current branch only.
- ../.git/config:11-14 - main tracking.
- Git log inspection found no SP1/SP2-labeled commit or tag in visible history.
- Git status inspection shows substantial current implementation outside committed history.

**Confidence:**  
Not verified.

**Report-safe statement:**  
The repository does not provide an auditable SP1 baseline, so phase attribution requires student-maintained history or documentation.

---

### Question 45
**Answer:**  
Verified SP2 additions/refinements cannot be separated from SP1 using repository evidence. Git history contains implementation and CI commits but no SP2 boundary, while current AI, Notification Hub, manager, and health-refinement modules are untracked. Migration dates alone do not prove academic phase ownership.

**Evidence:**  
- Git log: visible commits include general update/CI descriptions but no SP2 marker.
- Git status: ai_meals, ai_service_runtime, notification_hub, manager, and related migrations are untracked.
- vitamate_backend/core/migrations/0030_remove_healthstatedelta_notification_candidates_and_more.py:1-20 - migration without SP phase label.

**Confidence:**  
Not verified.

**Report-safe statement:**  
SP2 additions cannot be stated safely until the students provide a dated phase boundary, tagged baseline, or approved feature-change record.

---

### Question 46
**Answer:**  
Three challenges are explicitly evidenced. First, some Windows CUDA/Ultralytics combinations returned empty YOLO masks; the runtime defaults that path to CPU and retries once on CPU, with CPU latency as the limitation. Second, automatic weight is not reliable enough for the app contract; the integration forces manual confirmation and keeps Depth Anything optional. Third, concurrent/retried meal finalization could duplicate records; the service locks user/session and applies a unique finalization key, requiring clients to preserve idempotency keys.

**Evidence:**  
- .local/vitamate_ai_runtime/src/vitamate_ai_package/segmentation/yolo_segmenter.py:94-143 - CUDA empty-mask challenge and CPU retry.
- .local/vitamate_ai_runtime/FULL_PIPELINE_LOCAL_TESTING.md:24-38 - manual-weight default.
- vitamate_backend/ai_service_runtime/secure_app.py:45-53 - enforced skip mode.
- vitamate_backend/core/services/nutrition/meal_finalization_service.py:54-65 - lock and duplicate lookup.
- vitamate_backend/core/models/nutrition.py:561-569 - database uniqueness.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Documented challenges include GPU mask instability, unreliable automatic weight estimation, and retry-safe meal finalization, each addressed by explicit runtime or transaction safeguards.

---

### Question 47
**Answer:**  
Missing or incomplete evidence includes: one reconciled AI dependency environment; verified Android Studio/PyCharm/API/database-tool usage; documented branch/PR strategy; production/staging/mobile-release deployment; physical-device execution evidence; complete AI training datasets, licenses, annotations, scripts, batch size, optimizer, learning rate, augmentation, and hardware; auditable SP1/SP2 boundary; and actual 6-8 screenshots. Core versions, database, dependency files, CI, test environment, tree, modules, code examples, and accessible inference implementation are available.

**Evidence:**  
- .local/vitamate_ai_runtime/requirements-ai-runtime.lock.txt:40-219 - lock values differ from installed runtime.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:12-18 - excluded training/evaluation assets.
- ../.git/config:11-14 - only main tracking documented.
- ../.github/workflows/ci.yml:20-296 - CI without deployment.
- vitamate_frontend/lib/app.dart:43-82 - source screens exist, but code is not screenshot evidence.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Chapter 6 can document implementation architecture and local/CI environments, but tool-use, deployment, phase-history, training-provenance, and screenshot evidence require manual completion.

---

### Question 48
**Answer:**  

Confirmed facts:
- Flutter communicates with AI through Django only.
- PostgreSQL is principal; SQLite is opt-in development fallback.
- Django/DRF, Flutter/Dart, local PostgreSQL, and current local AI import versions are verifiable.
- Notification planning is backend-owned and Android delivery is local.
- Final nutrition comes from the Django canonical catalog after confirmation.
- Constraints and Health Tracker Coordinator are real Django services.

Partially confirmed facts:
- AI runtime versions are observable locally but conflict with the generated lock.
- Fine-tuning artifacts and split counts exist, but full training inputs/procedure are external.
- Physical-device execution is documented but not evidenced as a repository test run.
- Current untracked modules are implemented locally but absent from committed history/current CI.

Unverified facts:
- Production/staging deployment and HTTPS operation.
- App-store/mobile release and Dockerized application deployment.
- Complete branch/PR strategy and SP1/SP2 boundary.
- Android Studio, PyCharm, Postman, or database GUI usage.
- Complete model dataset provenance/licenses and reproducible training.

Contradictions or outdated assumptions:
- CURRENT_STATE.md and MODEL_REGISTRY.md describe foodv1 as primary and fine-tuned semantics as inactive, while current manifests select seed17 and an accepted dish checkpoint.
- requirements-ai-runtime.lock.txt differs from the installed AI environment.
- FULL_PIPELINE_LOCAL_TESTING.md documents pytest and smoke_test_egg_salad_models.py, but pytest is not installed and the script is absent.
- Bundled AI documentation describes /finalize, but active Django calls only /analyze and performs canonical finalization itself.

**Evidence:**  
- .local/vitamate_ai_runtime/CURRENT_STATE.md:20-23 - outdated model description.
- .local/vitamate_ai_runtime/MODEL_REGISTRY.md:7-8 - outdated primary registry.
- .local/vitamate_ai_runtime/models/segmentation/active_model.json:5-10 - current primary.
- .local/vitamate_ai_runtime/models/semantics/active_models.json:2-5 - current dish model.
- .local/vitamate_ai_runtime/FULL_PIPELINE_LOCAL_TESTING.md:49-57 - unavailable test commands.
- vitamate_backend/ai_meals/gateway.py:35-40 - active gateway calls /analyze only.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
Current manifests, executable configuration, and source paths are authoritative; older AI state documents and the unreconciled AI lock require correction.

---

### Question 49
**Answer:**  
Minimum guide evidence:

- Folder-tree figure: Question 23, grounded by vitamate_backend/vitamate_project/settings_base.py:77-91 and vitamate_frontend/lib/app.dart:33-103.
- API excerpt: vitamate_backend/ai_meals/views.py:27-43.
- ORM excerpt: vitamate_backend/core/repositories/nutrition/meal_log_repository.py:17-34.
- Business-logic excerpt: vitamate_backend/core/services/nutrition/meal_finalization_service.py:51-65.
- UI screenshots: HomeScreen, NutritionDashboardScreen, ActivityScreen, StatsScreen, MedicationsScreen, HabitsScreen, ChronicConditionsScreen, and MyVitaMateScreen.
- AI excerpt: vitamate_backend/ai_meals/gateway.py:29-43.

**Evidence:**  
- vitamate_frontend/lib/app.dart:43-82 - recommended route-backed screens.
- vitamate_backend/ai_meals/views.py:27-43 - API validation/delegation.
- vitamate_backend/core/repositories/nutrition/meal_log_repository.py:17-34 - owner-scoped ORM.
- vitamate_backend/core/services/nutrition/meal_finalization_service.py:51-65 - transaction/idempotency.
- vitamate_backend/ai_meals/gateway.py:29-43 - AI integration boundary.

**Confidence:**  
Confirmed.

**Report-safe statement:**  
A minimal evidence set can be assembled from one project tree, three short backend excerpts, eight route-backed screenshots, and one Django-to-AI gateway excerpt.

---

### Question 50
**Answer:**  
1. Accept with qualification: main versions are verifiable, but AI installed environment and lock conflict.
2. Accept: PostgreSQL is principal.
3. Accept: SQLite is optional local development only.
4. Accept: active dependency files are identified.
5. Accept with qualification: local and CI environments are documented; production and physical-device execution are not.
6. Partial: GitHub/main are verified; branch strategy is not.
7. Accept: GitHub Actions CI is verified and deployment is absent.
8. Accept: the active tree can be generated.
9. Accept: representative API, ORM, and business excerpts are available.
10. Accept: route-backed screenshot candidates are identified.
11. Accept: Flutter calls Django, not FastAPI.
12. Accept with qualification: accessible active models/checkpoints are verified; absent/external assets are identified.
13. Partial: limited training metadata is verified; complete datasets/configuration are unavailable.
14. Accept: final nutrition uses VitaMate's canonical catalog.
15. Accept: no production LLM recommendation service exists in the inspected implementation; AI scope is meal-image analysis.

**Evidence:**  
- vitamate_backend/vitamate_project/settings_base.py:57-72,125-146 - database, JWT, AI configuration.
- vitamate_frontend/lib/features/nutrition/data/ai_meal_api.dart:8-90 - Flutter calls Django only.
- vitamate_backend/core/services/nutrition/meal_finalization_service.py:202-259 - canonical finalization.
- ../.github/workflows/ci.yml:3-296 - CI and no deployment.
- .local/vitamate_ai_runtime/docs/AI_RUNTIME_PACKAGE_MANIFEST.md:12-18 - unavailable training assets.
- Repository search found no LLM service or LLM dependency; intelligent routes are meal-image analyze/finalize only.

**Confidence:**  
Confirmed with stated qualifications.

**Report-safe statement:**  
The repository sufficiently proves current software implementation and local/CI environment, but not deployment, complete model training provenance, branch strategy, or SP1/SP2 history.

---

**Chapter 6 evidence sufficient:** No

**Remaining manual information required from the students:** actual IDE/tool usage beyond VS Code; approved SP1 baseline and SP2 change list with dates; branch and pull-request process; production/staging/release status; physical-device test evidence if claimed; final 6-8 screenshots; AI dependency-lock reconciliation; and original training dataset sources, licenses, annotations, complete hyperparameters, hardware, and output-run provenance.
