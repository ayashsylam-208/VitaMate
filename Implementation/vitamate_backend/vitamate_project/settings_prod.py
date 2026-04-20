from .settings_base import *  # noqa: F401,F403


SECRET_KEY = env_required("DJANGO_SECRET_KEY")

DEBUG = False

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")

CORS_ALLOWED_ORIGINS = env_list("DJANGO_CORS_ALLOWED_ORIGINS")

REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_RENDERER_CLASSES": (
        "rest_framework.renderers.JSONRenderer",
    ),
}

DATABASES = postgres_database_config()

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True

# HSTS and forced HTTPS are intentionally left env-gated for deployments that
# terminate TLS at a proxy or run staging without HTTPS.
if env_bool("DJANGO_SECURE_SSL_REDIRECT", False):
    SECURE_SSL_REDIRECT = True

if env_bool("DJANGO_ENABLE_HSTS", False):
    SECURE_HSTS_SECONDS = int(env_required("DJANGO_SECURE_HSTS_SECONDS"))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = env_bool(
        "DJANGO_SECURE_HSTS_INCLUDE_SUBDOMAINS",
        False,
    )
    SECURE_HSTS_PRELOAD = env_bool("DJANGO_SECURE_HSTS_PRELOAD", False)
