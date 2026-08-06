import os

from .settings_base import *  # noqa: F401,F403


SECRET_KEY = os.getenv(
    "DJANGO_SECRET_KEY",
    "django-insecure-^l0w3b!!fku1jc$#w8vuhe)7uf11_c^85l*x_6t#i&ekb&3y87",
)

DEBUG = True

ALLOWED_HOSTS = env_list(
    "DJANGO_ALLOWED_HOSTS",
    default=[
        "localhost",
        "127.0.0.1",
        "10.0.2.2",
    ],
)
for host in ["localhost", "127.0.0.1", "10.0.2.2", "testserver"]:
    if host not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(host)

# Local Android devices usually reach the dev server through a changing LAN IP.
# In development only, accept any Host header to prevent repeated breakage after
# network or router changes. Production settings never import this module.
if env_bool("DJANGO_DEV_ALLOW_ALL_HOSTS", default=True) and "*" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("*")

CORS_ALLOWED_ORIGINS = env_list(
    "DJANGO_CORS_ALLOWED_ORIGINS",
    default=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
)

if env_bool("DJANGO_DEV_CORS_ALLOW_ALL", default=True):
    CORS_ALLOW_ALL_ORIGINS = True

REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_RENDERER_CLASSES": (
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ),
}

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

if os.getenv("VITAMATE_USE_SQLITE") == "1":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
else:
    DATABASES = postgres_database_config()

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "django.server": {
            "()": "django.utils.log.ServerFormatter",
            "format": "[{server_time}] {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "stream": "ext://sys.stdout",
        },
        "django.server": {
            "class": "logging.StreamHandler",
            "formatter": "django.server",
            "stream": "ext://sys.stdout",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": os.getenv("DJANGO_LOG_LEVEL", "INFO"),
    },
    "loggers": {
        "django.request": {
            "handlers": ["console"],
            "level": "WARNING",
            "propagate": False,
        },
        "django.server": {
            "handlers": ["django.server"],
            "level": "INFO",
            "propagate": False,
        },
    },
}
