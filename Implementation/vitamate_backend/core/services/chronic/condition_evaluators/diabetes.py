from __future__ import annotations

from core.services.chronic.condition_evaluators.base import BaseConditionEvaluator


class DiabetesEvaluator(BaseConditionEvaluator):
    HYPOGLYCEMIA_THRESHOLD = 70
    FASTING_MIN = 80
    FASTING_MAX = 130
    AFTER_MEAL_MAX = 180
    BEDTIME_MIN = 90
    BEDTIME_MAX = 150

    def get_restrictions(self, user_condition, latest_record=None) -> list[dict]:
        if latest_record is None:
            return []
        value = self._numeric(latest_record.value_1 or latest_record.value)
        if value is None:
            return []
        if value < self.HYPOGLYCEMIA_THRESHOLD:
            return [
                {
                    "code": "avoid_skipping_meals",
                    "severity": "high",
                    "message": "Avoid skipping the next meal and review fast-acting carbohydrate access.",
                }
            ]
        if self.classify_reading(user_condition, latest_record) == "high":
            return [
                {
                    "code": "reduce_simple_sugars",
                    "severity": "medium",
                    "message": "Limit simple sugars and moderate the next carbohydrate-heavy meal.",
                }
            ]
        return []

    def get_target_ranges(self, user_condition) -> list[dict]:
        profile = user_condition.profile_data or {}
        fasting_max = self._numeric(profile.get("glucose_target"), default=self.FASTING_MAX)
        added_sugar_limit = self._numeric(
            profile.get("added_sugars_limit"),
            default=25,
        )
        return [
            self._base_target(
                target_key="fasting_glucose",
                target_name="Fasting glucose goal",
                category="monitoring",
                metric_key="fasting_glucose",
                evaluation_mode="latest_indicator",
                unit="mg/dL",
                min_value=self.FASTING_MIN,
                max_value=fasting_max,
                guidance="Use your fasting or before-meal glucose readings to stay within range.",
                is_scored=False,
            ),
            self._base_target(
                target_key="postprandial_glucose",
                target_name="After-meal glucose goal",
                category="monitoring",
                metric_key="postprandial_glucose",
                evaluation_mode="latest_indicator",
                unit="mg/dL",
                min_value=None,
                max_value=self.AFTER_MEAL_MAX,
                guidance="After-meal glucose should stay at or below the post-meal goal.",
                is_scored=False,
            ),
            self._base_target(
                target_key="added_sugars_g",
                target_name="Added sugar limit",
                category="nutrition",
                metric_key="added_sugars_g",
                evaluation_mode="daily_total",
                unit="g/day",
                min_value=None,
                max_value=added_sugar_limit,
                guidance="Keep added sugars at or below the daily diabetes limit.",
                is_scored=True,
            ),
        ]

    def classify_reading(self, user_condition, latest_record) -> str:
        value = self._numeric(latest_record.value_1 or latest_record.value, default=0)
        context = (latest_record.reading_context or "fasting").strip().lower()
        if value < self.HYPOGLYCEMIA_THRESHOLD:
            return "low"
        if context in {"fasting", "before_meal"}:
            return "in_range" if self.FASTING_MIN <= value <= self.FASTING_MAX else "high"
        if context == "after_meal":
            return "in_range" if value <= self.AFTER_MEAL_MAX else "high"
        if context == "bedtime":
            return "in_range" if self.BEDTIME_MIN <= value <= self.BEDTIME_MAX else "high"
        return "in_range" if self.FASTING_MIN <= value <= self.FASTING_MAX else "high"

    def evaluate_risk(self, user_condition, latest_record=None) -> dict:
        if latest_record is None:
            return {
                "status": "stable",
                "risk_level": "low",
                "risk_flags": [],
                "tracker_impacts": [],
            }

        value = self._numeric(latest_record.value_1 or latest_record.value, default=0)
        classification = self.classify_reading(user_condition, latest_record)
        if value < 54:
            return {
                "status": "critical",
                "risk_level": "critical",
                "risk_flags": ["severe_hypoglycemia_risk"],
                "tracker_impacts": [],
            }
        if classification == "low":
            return {
                "status": "attention_needed",
                "risk_level": "high",
                "risk_flags": ["hypoglycemia_risk"],
                "tracker_impacts": [
                    self._tracker_impact(
                        tracker="nutrition",
                        key="avoid_long_fasting",
                        value=True,
                        label="Avoid long fasting gaps",
                        guidance="Keep the next meal balanced and available on time.",
                    )
                ],
            }
        if value >= 250:
            added_sugar_limit = 15
            risk_level = "high"
            flags = ["hyperglycemia_risk"]
        elif classification == "high":
            added_sugar_limit = 20
            risk_level = "medium"
            flags = ["hyperglycemia_risk"]
        else:
            added_sugar_limit = 25
            risk_level = "low"
            flags = []
        return {
            "status": "stable" if classification == "in_range" else "attention_needed",
            "risk_level": risk_level,
            "risk_flags": flags,
            "tracker_impacts": [
                self._tracker_impact(
                    tracker="nutrition",
                    key="added_sugars_g",
                    value=added_sugar_limit,
                    label="Added sugar limit",
                    unit="g/day",
                    category="nutrition",
                    metric_key="added_sugars_g",
                    evaluation_mode="daily_total",
                    guidance="Prefer lower-sugar meals while glucose remains elevated.",
                )
            ]
            if classification == "high"
            else [],
        }

    def build_recommendations(self, user_condition, evaluation, latest_record=None) -> list[dict]:
        if latest_record is None:
            return []
        classification = self.classify_reading(user_condition, latest_record)
        if classification == "low":
            return [
                {
                    "code": "take_fast_carbs_if_needed",
                    "message": "Use a fast-acting carbohydrate plan if symptoms match your clinician guidance.",
                }
            ]
        if classification == "high":
            return [
                {
                    "code": "prefer_low_sugar_next_meal",
                    "message": "Choose a lower sugar meal for your next entry.",
                },
                {
                    "code": "hydrate_with_unsweetened_drinks",
                    "message": "Prefer water or unsweetened drinks for the rest of the day.",
                },
            ]
        return [
            {
                "code": "maintain_glucose_routine",
                "message": "Keep using the same meal and hydration routine while glucose stays in range.",
            }
        ]
