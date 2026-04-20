from __future__ import annotations

from copy import deepcopy

from django.contrib.auth import get_user_model
from django.db import transaction

class HealthStateEventPublisher:
    @staticmethod
    def publish_on_commit(
        *,
        user,
        trigger_type: str,
        payload: dict | None = None,
        synchronous: bool = True,
    ) -> None:
        user_id = getattr(user, "id", user)
        payload_copy = deepcopy(payload or {})

        def _callback():
            user_model = get_user_model()
            user_obj = user_model.objects.filter(pk=user_id).first()
            if user_obj is None:
                return
            from core.services.orchestration.health_state_orchestrator import (
                HealthStateOrchestrator,
            )

            HealthStateOrchestrator().handle_event(
                user=user_obj,
                trigger_type=trigger_type,
                payload=payload_copy,
                synchronous=synchronous,
            )

        transaction.on_commit(_callback)
