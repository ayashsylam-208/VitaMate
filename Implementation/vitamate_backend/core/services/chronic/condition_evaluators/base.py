from __future__ import annotations

from abc import ABC, abstractmethod


class BaseConditionEvaluator(ABC):
    @abstractmethod
    def get_restrictions(self, user_condition, latest_record=None) -> list[dict]:
        raise NotImplementedError

    @abstractmethod
    def get_target_ranges(self, user_condition) -> list[dict]:
        raise NotImplementedError

    @abstractmethod
    def evaluate_risk(self, user_condition, latest_record=None) -> dict:
        raise NotImplementedError

    @abstractmethod
    def classify_reading(self, user_condition, latest_record) -> str:
        raise NotImplementedError

    @abstractmethod
    def build_recommendations(self, user_condition, evaluation, latest_record=None) -> list[dict]:
        raise NotImplementedError

    @staticmethod
    def _numeric(value, *, default: float | None = None) -> float | None:
        if value in (None, ""):
            return default
        try:
            return float(value)
        except (TypeError, ValueError):
            return default

    @staticmethod
    def _base_target(
        *,
        target_key: str,
        target_name: str,
        category: str,
        metric_key: str,
        evaluation_mode: str,
        unit: str,
        min_value: float | None = None,
        max_value: float | None = None,
        guidance: str = "",
        priority: int = 2,
        is_scored: bool = True,
    ) -> dict:
        return {
            "target_key": target_key,
            "target_name": target_name,
            "category": category,
            "metric_key": metric_key,
            "evaluation_mode": evaluation_mode,
            "unit": unit,
            "min_value": min_value,
            "max_value": max_value,
            "guidance": guidance,
            "priority": priority,
            "is_scored": is_scored,
        }

    @staticmethod
    def _tracker_impact(
        *,
        tracker: str,
        key: str,
        value,
        label: str,
        unit: str = "",
        category: str = "",
        metric_key: str = "",
        evaluation_mode: str = "",
        guidance: str = "",
    ) -> dict:
        return {
            "tracker": tracker,
            "key": key,
            "value": value,
            "label": label,
            "unit": unit,
            "category": category,
            "metric_key": metric_key or key,
            "evaluation_mode": evaluation_mode,
            "guidance": guidance,
        }
