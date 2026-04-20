from __future__ import annotations

from core.services.chronic.condition_evaluators.base import BaseConditionEvaluator


class HypertensionEvaluator(BaseConditionEvaluator):
    CONTROLLED_SYSTOLIC = 130
    CONTROLLED_DIASTOLIC = 80
    HIGH_SYSTOLIC = 140
    HIGH_DIASTOLIC = 90
    CRITICAL_SYSTOLIC = 180
    CRITICAL_DIASTOLIC = 120

    def get_restrictions(self, user_condition, latest_record=None) -> list[dict]:
        if latest_record is None:
            return []
        classification = self.classify_reading(user_condition, latest_record)
        if classification == "high":
            return [
                {
                    "code": "reduce_sodium_intake",
                    "severity": "high" if latest_record.risk_level == "critical" else "medium",
                    "message": "Tighten sodium intake and avoid heavily salted meals while blood pressure remains high.",
                }
            ]
        if classification == "elevated":
            return [
                {
                    "code": "maintain_dash_pattern",
                    "severity": "medium",
                    "message": "Stay close to a DASH-style pattern and keep sodium low.",
                }
            ]
        return []

    def get_target_ranges(self, user_condition) -> list[dict]:
        profile = user_condition.profile_data or {}
        systolic = self._numeric(profile.get("systolic_target"), default=self.CONTROLLED_SYSTOLIC - 1)
        diastolic = self._numeric(profile.get("diastolic_target"), default=self.CONTROLLED_DIASTOLIC - 1)
        sodium_limit = self._numeric(profile.get("sodium_limit"), default=1500)
        return [
            self._base_target(
                target_key="blood_pressure_systolic",
                target_name="Systolic blood pressure",
                category="monitoring",
                metric_key="blood_pressure_systolic",
                evaluation_mode="latest_indicator",
                unit="mm Hg",
                max_value=systolic,
                guidance="Keep systolic pressure below the target range.",
                is_scored=False,
            ),
            self._base_target(
                target_key="blood_pressure_diastolic",
                target_name="Diastolic blood pressure",
                category="monitoring",
                metric_key="blood_pressure_diastolic",
                evaluation_mode="latest_indicator",
                unit="mm Hg",
                max_value=diastolic,
                guidance="Keep diastolic pressure below the target range.",
                is_scored=False,
            ),
            self._base_target(
                target_key="sodium_mg",
                target_name="Daily sodium ceiling",
                category="nutrition",
                metric_key="sodium_mg",
                evaluation_mode="daily_total",
                unit="mg/day",
                max_value=sodium_limit,
                guidance="Sodium remains one of the clearest modifiable nutrition levers for blood pressure.",
            ),
        ]

    def classify_reading(self, user_condition, latest_record) -> str:
        systolic = self._numeric(latest_record.value_1, default=0)
        diastolic = self._numeric(latest_record.value_2, default=0)
        if systolic >= self.HIGH_SYSTOLIC or diastolic >= self.HIGH_DIASTOLIC:
            return "high"
        if systolic >= self.CONTROLLED_SYSTOLIC or diastolic >= self.CONTROLLED_DIASTOLIC:
            return "elevated"
        return "controlled"

    def evaluate_risk(self, user_condition, latest_record=None) -> dict:
        if latest_record is None:
            return {
                "status": "stable",
                "risk_level": "low",
                "risk_flags": [],
                "tracker_impacts": [],
            }

        systolic = self._numeric(latest_record.value_1, default=0)
        diastolic = self._numeric(latest_record.value_2, default=0)
        classification = self.classify_reading(user_condition, latest_record)
        if systolic >= self.CRITICAL_SYSTOLIC or diastolic >= self.CRITICAL_DIASTOLIC:
            sodium_limit = 1200
            return {
                "status": "critical",
                "risk_level": "critical",
                "risk_flags": ["blood_pressure_critical"],
                "tracker_impacts": [
                    self._tracker_impact(
                        tracker="nutrition",
                        key="sodium_mg",
                        value=sodium_limit,
                        label="Emergency sodium ceiling",
                        unit="mg/day",
                        category="nutrition",
                        metric_key="sodium_mg",
                        evaluation_mode="daily_total",
                        guidance="Use a stricter sodium ceiling until follow-up is logged.",
                    ),
                    self._tracker_impact(
                        tracker="activity",
                        key="exercise_intensity_mode",
                        value="conservative",
                        label="Conservative activity mode",
                        guidance="Avoid aggressive intensity while pressure remains critical.",
                    ),
                ],
            }

        if classification == "high":
            sodium_limit = 1500
            return {
                "status": "attention_needed",
                "risk_level": "high",
                "risk_flags": ["high_blood_pressure_risk"],
                "tracker_impacts": [
                    self._tracker_impact(
                        tracker="nutrition",
                        key="sodium_mg",
                        value=sodium_limit,
                        label="Daily sodium ceiling",
                        unit="mg/day",
                        category="nutrition",
                        metric_key="sodium_mg",
                        evaluation_mode="daily_total",
                        guidance="Use the stricter sodium ceiling while blood pressure remains high.",
                    ),
                    self._tracker_impact(
                        tracker="activity",
                        key="exercise_intensity_mode",
                        value="moderate",
                        label="Moderate activity mode",
                        guidance="Favor regular moderate movement until blood pressure improves.",
                    ),
                ],
            }

        if classification == "elevated":
            return {
                "status": "attention_needed",
                "risk_level": "medium",
                "risk_flags": ["elevated_blood_pressure"],
                "tracker_impacts": [
                    self._tracker_impact(
                        tracker="nutrition",
                        key="sodium_mg",
                        value=1800,
                        label="Temporary sodium ceiling",
                        unit="mg/day",
                        category="nutrition",
                        metric_key="sodium_mg",
                        evaluation_mode="daily_total",
                        guidance="Keep sodium low and recheck blood pressure soon.",
                    )
                ],
            }

        return {
            "status": "stable",
            "risk_level": "low",
            "risk_flags": [],
            "tracker_impacts": [],
        }

    def build_recommendations(self, user_condition, evaluation, latest_record=None) -> list[dict]:
        risk_flags = set(evaluation.get("risk_flags") or [])
        if "blood_pressure_critical" in risk_flags:
            return [
                {
                    "code": "seek_urgent_bp_followup",
                    "message": "If this reading is unexpected or symptomatic, follow your urgent blood-pressure action plan.",
                }
            ]
        if "high_blood_pressure_risk" in risk_flags:
            return [
                {
                    "code": "choose_low_sodium_next_meal",
                    "message": "Choose a lower sodium meal for your next nutrition entry.",
                },
                {
                    "code": "log_bp_again_after_rest",
                    "message": "Rest quietly and log another blood pressure reading when appropriate.",
                },
            ]
        if "elevated_blood_pressure" in risk_flags:
            return [
                {
                    "code": "maintain_sodium_awareness",
                    "message": "Keep sodium low for the rest of the day and continue regular light movement.",
                }
            ]
        return [
            {
                "code": "maintain_bp_routine",
                "message": "Keep following the same low-sodium and routine-monitoring plan while blood pressure stays controlled.",
            }
        ]
