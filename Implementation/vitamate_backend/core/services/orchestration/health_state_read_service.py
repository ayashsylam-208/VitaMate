from core.models import UnifiedHealthState
from core.repositories.health_state_repository import HealthStateRepository


class HealthStateReadService:
    @staticmethod
    def get_current_state(*, user, state_date):
        return HealthStateRepository.get_state(
            user=user,
            state_date=state_date,
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        )

    @staticmethod
    def list_daily_states(*, user, start_date, end_date):
        return HealthStateRepository.list_states(
            user=user,
            start_date=start_date,
            end_date=end_date,
            window_kind=UnifiedHealthState.WINDOW_DAILY,
        )
