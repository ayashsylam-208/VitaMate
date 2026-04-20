from __future__ import annotations

from typing import Any, Protocol


class AIRecommendationAdvisor(Protocol):
    def generate_recommendations(
        self,
        *,
        user_id: int,
        tracker_snapshot: dict[str, Any],
    ) -> list[dict[str, Any]]:
        ...


class MealImageAnalysisService(Protocol):
    def generate_meal_entry(self, *, image_ref: str) -> dict[str, Any]:
        ...


class ChronicConditionTracker(Protocol):
    def evaluate_risk(self, *, user_id: int) -> dict[str, Any]:
        ...


class HabitCessationTracker(Protocol):
    def evaluate_reduction_progress(self, *, user_id: int) -> dict[str, Any]:
        ...


class MicronutrientTracker(Protocol):
    def evaluate_deficiency_risk(self, *, user_id: int) -> dict[str, Any]:
        ...

