"""
Shared Django settings for VitaMate.

Environment-specific modules should import from this file and only override
settings that differ between development and production.
"""
import os
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent


def load_local_env(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        os.environ.setdefault(key, value)


load_local_env(PROJECT_ROOT / ".env")


def env_bool(name, default=False):
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_list(name, default=None):
    value = os.getenv(name)
    if value is None or value.strip() == "":
        return list(default or [])
    return [item.strip() for item in value.split(",") if item.strip()]


def env_required(name):
    value = os.getenv(name)
    if value is None or value.strip() == "":
        raise RuntimeError(f"{name} environment variable is required.")
    return value


def postgres_database_config():
    return {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.getenv("POSTGRES_DB", "vitamate"),
            "USER": os.getenv("POSTGRES_USER", "vitamate"),
            "PASSWORD": os.getenv("POSTGRES_PASSWORD", "vitamate"),
            "HOST": os.getenv("POSTGRES_HOST", "localhost"),
            "PORT": os.getenv("POSTGRES_PORT", "5432"),
            "OPTIONS": {"client_encoding": "UTF8"},
            "TEST": {
                "CHARSET": "UTF8",
                "TEMPLATE": "template0",
            },
        }
    }


BASE_DIR = PROJECT_ROOT

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "corsheaders",
    "users.apps.UsersConfig",
    "core",
    "gamification",
    "notification_hub.apps.NotificationHubConfig",
    "manager.apps.ManagerConfig",
    "ai_meals.apps.AiMealsConfig",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "core.middleware.PerformanceInstrumentationMiddleware",
]

ROOT_URLCONF = "vitamate_project.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "vitamate_project.wsgi.application"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_SCHEMA_CLASS": "rest_framework.schemas.openapi.AutoSchema",
    # TODO: Consider adding IsAuthenticated globally after explicitly
    # validating every public auth endpoint and any intentionally public API.
}

PERFORMANCE_INSTRUMENTATION_ENABLED = env_bool(
    "PERFORMANCE_INSTRUMENTATION_ENABLED",
    default=True,
)

AI_MEALS_BASE_URL = os.getenv("AI_MEALS_BASE_URL", "http://127.0.0.1:8010").rstrip("/")
AI_MEALS_TIMEOUT_SECONDS = int(os.getenv("AI_MEALS_TIMEOUT_SECONDS", "180"))
AI_MEALS_SERVICE_TOKEN = os.getenv("AI_MEALS_SERVICE_TOKEN", "")
AI_MEALS_MAX_IMAGE_BYTES = int(os.getenv("AI_MEALS_MAX_IMAGE_BYTES", str(10 * 1024 * 1024)))
AI_MEALS_SESSION_TTL_MINUTES = int(os.getenv("AI_MEALS_SESSION_TTL_MINUTES", "30"))
AI_MEALS_MIN_IMAGE_DIMENSION = int(os.getenv("AI_MEALS_MIN_IMAGE_DIMENSION", "128"))
AI_MEALS_MAX_IMAGE_DIMENSION = int(os.getenv("AI_MEALS_MAX_IMAGE_DIMENSION", "8192"))
AI_MEALS_MAX_IMAGE_PIXELS = int(os.getenv("AI_MEALS_MAX_IMAGE_PIXELS", "40000000"))

CELERY_BROKER_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", CELERY_BROKER_URL)
CELERY_USE_BROKER = env_bool("CELERY_USE_BROKER", default=False)
CELERY_TASK_ALWAYS_EAGER = env_bool("CELERY_TASK_ALWAYS_EAGER", default=False)
CELERY_TASK_EAGER_PROPAGATES = env_bool(
    "CELERY_TASK_EAGER_PROPAGATES",
    default=True,
)

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": (
            "django.contrib.auth.password_validation."
            "UserAttributeSimilarityValidator"
        ),
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
