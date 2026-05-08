from __future__ import annotations

import os


try:
    from celery import Celery
except Exception:  # pragma: no cover - import guard for local environments without Celery installed
    app = None
else:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "vitamate_project.settings")

    app = Celery("vitamate")
    app.config_from_object("django.conf:settings", namespace="CELERY")
    app.autodiscover_tasks()
