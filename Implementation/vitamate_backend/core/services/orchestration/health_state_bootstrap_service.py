from __future__ import annotations

import json
import logging

from django.utils import timezone

from core.services.orchestration.health_state_orchestrator import HealthStateOrchestrator
from core.services.orchestration.health_state_read_service import HealthStateReadService
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class HealthStateBootstrapError(RuntimeError):
    pass


logger = logging.getLogger("vitamate.performance")


class HealthStateBootstrapService:
    @classmethod
    def ensure_initialized(cls, *, user, state_date=None):
        state_date = state_date or timezone.localdate()
        reader = HealthStateReadService()
        existing = reader.get_current_state(user=user, state_date=state_date)
        if existing is not None:
            return existing

        logger.info(
            json.dumps(
                {
                    "event": "health_state_bootstrap_requested",
                    "user_id": user.id,
                    "state_date": state_date.isoformat(),
                    "reason": "missing_materialized_state",
                }
            )
        )

        HealthStateOrchestrator().handle_event(
            user=user,
            trigger_type=HealthStateTriggers.HEALTH_STATE_BOOTSTRAP,
            payload={
                "trigger_reference": f"bootstrap:{user.id}:{state_date}",
                "idempotency_key": f"health-state-bootstrap:{user.id}:{state_date}",
                "event_dates": [state_date],
                "today": state_date,
            },
            synchronous=True,
        )
        state = reader.get_current_state(user=user, state_date=state_date)
        if state is None:
            raise HealthStateBootstrapError(
                f"Persisted health state was not created for user {user.id}."
            )
        return state
