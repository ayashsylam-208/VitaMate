from __future__ import annotations

from datetime import date
from threading import Thread

from django.conf import settings
from django.contrib.auth import get_user_model

from core.models import ConstraintResolutionRun


try:
    from celery import shared_task
except Exception:  # pragma: no cover - exercised only when Celery is unavailable
    def shared_task(*decorator_args, **decorator_kwargs):
        def _decorate(fn):
            def _delay(*args, **kwargs):
                return _dispatch_callable(fn, *args, **kwargs)

            fn.delay = _delay
            return fn

        if decorator_args and callable(decorator_args[0]) and not decorator_kwargs:
            return _decorate(decorator_args[0])
        return _decorate


def _user_by_id(user_id: int):
    return get_user_model().objects.filter(pk=user_id).first()


def _dispatch_callable(task_callable, *args, **kwargs):
    if getattr(settings, "CELERY_TASK_ALWAYS_EAGER", False):
        return task_callable(*args, **kwargs)

    if kwargs.get("synchronous"):
        return task_callable(*args, **kwargs)

    if getattr(settings, "CELERY_USE_BROKER", False):
        try:
            return task_callable.delay(*args, **kwargs)
        except Exception:
            pass

    default_db = (getattr(settings, "DATABASES", {}) or {}).get("default", {})
    engine = str(default_db.get("ENGINE") or "")
    if "sqlite3" in engine:
        return None

    thread = Thread(
        target=task_callable,
        args=args,
        kwargs=kwargs,
        daemon=True,
    )
    thread.start()
    return None


def dispatch_health_state_event(**kwargs):
    return _dispatch_callable(enqueue_health_state_event, **kwargs)


def dispatch_constraint_recompute(**kwargs):
    return _dispatch_callable(enqueue_constraint_recompute, **kwargs)


def dispatch_read_model_refresh(**kwargs):
    return _dispatch_callable(enqueue_read_model_refresh, **kwargs)


@shared_task(name="vitamate.handle_health_state_event")
def enqueue_health_state_event(*, user_id: int, trigger_type: str, payload: dict | None = None, synchronous: bool = False):
    from core.services.orchestration.health_state_orchestrator import HealthStateOrchestrator

    user = _user_by_id(user_id)
    if user is None:
        return None
    return HealthStateOrchestrator().handle_event(
        user=user,
        trigger_type=trigger_type,
        payload=payload or {},
        synchronous=synchronous,
    )


@shared_task(name="vitamate.recompute_constraints")
def enqueue_constraint_recompute(
    *,
    user_id: int,
    trigger_type: str = ConstraintResolutionRun.TRIGGER_MANUAL,
    trigger_reference: str = "",
    tracker_type: str | None = None,
):
    from core.services.constraints.constraint_resolution_service import ConstraintResolutionService

    if tracker_type:
        return ConstraintResolutionService.recompute_tracker_constraints(
            user_id=user_id,
            tracker_type=tracker_type,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
        )
    return ConstraintResolutionService.resolve_for_user(
        user_id=user_id,
        trigger_type=trigger_type,
        trigger_reference=trigger_reference,
    )


@shared_task(name="vitamate.enqueue_read_model_refresh")
def enqueue_read_model_refresh(
    *,
    user_id: int,
    trigger_type: str,
    event_dates: list[str] | None = None,
):
    from core.services.orchestration.health_state_orchestrator import HealthStateOrchestrator

    user = _user_by_id(user_id)
    if user is None:
        return None
    payload = {
        "trigger_reference": f"read-model:{user_id}",
        "event_dates": list(event_dates or [str(date.today())]),
    }
    return HealthStateOrchestrator().handle_event(
        user=user,
        trigger_type=trigger_type,
        payload=payload,
        synchronous=False,
    )
