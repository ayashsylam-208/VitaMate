from __future__ import annotations

from typing import Any


class NoOpAIRecommendationAdvisor:
    def generate_recommendations(
        self,
        *,
        user_id: int,
        tracker_snapshot: dict[str, Any],
    ) -> list[dict[str, Any]]:
        return []


class NoOpMealImageAnalysisService:
    def generate_meal_entry(self, *, image_ref: str) -> dict[str, Any]:
        return {
            "image_ref": image_ref,
            "status": "not_implemented",
            "entries": [],
        }


class NoOpChronicConditionTracker:
    def evaluate_risk(self, *, user_id: int) -> dict[str, Any]:
        return {
            "user_id": user_id,
            "status": "not_implemented",
            "risk_level": "unknown",
        }


class NoOpHabitCessationTracker:
    def evaluate_reduction_progress(self, *, user_id: int) -> dict[str, Any]:
        return {
            "user_id": user_id,
            "status": "not_implemented",
            "progress": 0,
        }


class NoOpMicronutrientTracker:
    def evaluate_deficiency_risk(self, *, user_id: int) -> dict[str, Any]:
        return {
            "user_id": user_id,
            "status": "not_implemented",
            "deficiency_risk": "unknown",
        }

