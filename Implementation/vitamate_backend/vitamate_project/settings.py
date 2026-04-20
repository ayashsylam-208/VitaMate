"""
Compatibility settings entrypoint.

Keep DJANGO_SETTINGS_MODULE=vitamate_project.settings working, while loading
environment-specific settings from the split settings modules.
"""
import os


DJANGO_ENV = os.getenv("DJANGO_ENV", "dev").strip().lower()

if DJANGO_ENV in {"dev", "development", "local", ""}:
    from .settings_dev import *  # noqa: F401,F403
elif DJANGO_ENV in {"prod", "production"}:
    from .settings_prod import *  # noqa: F401,F403
else:
    raise RuntimeError(
        "Unsupported DJANGO_ENV value. Use 'dev' or 'prod'."
    )
