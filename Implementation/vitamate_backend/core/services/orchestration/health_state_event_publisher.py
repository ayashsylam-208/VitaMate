from __future__ import annotations

from copy import deepcopy

from django.db import transaction

from core.tasks import dispatch_health_state_event


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
            dispatch_health_state_event(
                user_id=user_id,
                trigger_type=trigger_type,
                payload=payload_copy,
                synchronous=synchronous,
            )

        transaction.on_commit(_callback)
