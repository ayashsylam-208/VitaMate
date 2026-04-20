from __future__ import annotations

from django.utils import timezone

from core.models import ConditionRuleProfile
from core.services.chronic.condition_evaluators.base import BaseConditionEvaluator


class DyslipidemiaEvaluator(BaseConditionEvaluator):
    DEFAULT_TRIGLYCERIDES_MAX = 150
    DEFAULT_HDL_MIN = 40
    DEFAULT_FOLLOWUP_INTERVAL_DAYS = 90

    def get_restrictions(self, user_condition, latest_record=None) -> list[dict]:
        evaluation = self.evaluate_risk(user_condition, latest_record=latest_record)
        restrictions = []
        if "lipid_risk" in set(evaluation.get("risk_flags") or []):
            restrictions.append(
                {
                    "code": "tighten_heart_healthy_fats",
                    "severity": "medium",
                    "message": "Favor unsaturated fats, fiber-rich meals, and avoid trans fat while lipid risk remains elevated.",
                }
            )
        if "followup_overdue" in set(evaluation.get("risk_flags") or []):
            restrictions.append(
                {
                    "code": "schedule_lipid_followup",
                    "severity": "medium",
                    "message": "A lipid follow-up is overdue; schedule the next panel when available.",
                }
            )
        return restrictions

    def get_target_ranges(self, user_condition) -> list[dict]:
        profile = user_condition.profile_data or {}
        ldl_target = self._ldl_target(user_condition)
        hdl_target = self._numeric(profile.get("hdl_target"), default=self.DEFAULT_HDL_MIN)
        triglyceride_target = self._numeric(
            profile.get("triglyceride_target"),
            default=self.DEFAULT_TRIGLYCERIDES_MAX,
        )
        return [
            self._base_target(
                target_key="ldl_cholesterol",
                target_name="LDL cholesterol goal",
                category="monitoring",
                metric_key="ldl_cholesterol",
                evaluation_mode="latest_indicator",
                unit="mg/dL",
                max_value=ldl_target,
                guidance="Use the latest lipid panel LDL value for follow-up.",
                is_scored=False,
            ),
            self._base_target(
                target_key="hdl_cholesterol",
                target_name="HDL cholesterol support",
                category="monitoring",
                metric_key="hdl_cholesterol",
                evaluation_mode="latest_indicator",
                unit="mg/dL",
                min_value=hdl_target,
                guidance="Higher HDL usually supports a healthier lipid pattern.",
                is_scored=False,
            ),
            self._base_target(
                target_key="triglycerides",
                target_name="Triglycerides goal",
                category="monitoring",
                metric_key="triglycerides",
                evaluation_mode="latest_indicator",
                unit="mg/dL",
                max_value=triglyceride_target,
                guidance="Keep triglycerides within the target range on the most recent panel.",
                is_scored=False,
            ),
        ]

    def classify_reading(self, user_condition, latest_record) -> str:
        payload = latest_record.payload or {}
        ldl = self._numeric(payload.get("ldl"), default=latest_record.value_1)
        hdl = self._numeric(payload.get("hdl"))
        triglycerides = self._numeric(payload.get("triglycerides"), default=latest_record.value_3)
        if (
            ldl is not None
            and ldl <= self._ldl_target(user_condition)
            and (hdl is None or hdl >= self.DEFAULT_HDL_MIN)
            and (triglycerides is None or triglycerides <= self.DEFAULT_TRIGLYCERIDES_MAX)
        ):
            return "controlled"
        return "high"

    def evaluate_risk(self, user_condition, latest_record=None) -> dict:
        risk_flags = []
        tracker_impacts = [
            self._tracker_impact(
                tracker="activity",
                key="activity_minutes_7d",
                value=150,
                label="Weekly activity goal",
                unit="minutes/week",
                category="activity",
                metric_key="activity_minutes_7d",
                evaluation_mode="rolling_7d_total",
                guidance="Regular weekly movement supports a better lipid pattern.",
            ),
            self._tracker_impact(
                tracker="medication",
                key="adherence_priority",
                value="high",
                label="Medication adherence priority",
                guidance="Lipid management is more stable when medication adherence stays consistent.",
            ),
        ]

        if latest_record is not None and self.classify_reading(user_condition, latest_record) != "controlled":
            risk_flags.append("lipid_risk")
            tracker_impacts.append(
                self._tracker_impact(
                    tracker="nutrition",
                    key="saturated_fat_pct_kcal",
                    value=6,
                    label="Saturated fat limit",
                    unit="% kcal",
                    category="nutrition",
                    metric_key="saturated_fat_pct_kcal",
                    evaluation_mode="daily_ratio",
                    guidance="Keep saturated fat low while lipid risk remains elevated.",
                )
            )

        last_record = latest_record or user_condition.indicator_records.filter(indicator_type="lipid_panel").first()
        followup_interval = self._numeric(
            (user_condition.profile_data or {}).get("followup_interval_days"),
            default=self.DEFAULT_FOLLOWUP_INTERVAL_DAYS,
        )
        if last_record is None:
            risk_flags.append("followup_overdue")
        else:
            age_days = (timezone.now() - last_record.recorded_at).days
            if followup_interval is not None and age_days > followup_interval:
                risk_flags.append("followup_overdue")

        if "followup_overdue" in risk_flags and "lipid_risk" in risk_flags:
            status = "attention_needed"
            risk_level = "high"
        elif "lipid_risk" in risk_flags or "followup_overdue" in risk_flags:
            status = "attention_needed"
            risk_level = "medium"
        else:
            status = "stable"
            risk_level = "low"

        return {
            "status": status,
            "risk_level": risk_level,
            "risk_flags": risk_flags,
            "tracker_impacts": tracker_impacts,
        }

    def build_recommendations(self, user_condition, evaluation, latest_record=None) -> list[dict]:
        flags = set(evaluation.get("risk_flags") or [])
        recommendations = []
        if "lipid_risk" in flags:
            recommendations.append(
                {
                    "code": "prefer_unsaturated_fats",
                    "message": "Choose meals with more unsaturated fats and fiber for the next few entries.",
                }
            )
        if "followup_overdue" in flags:
            recommendations.append(
                {
                    "code": "schedule_lipid_panel",
                    "message": "Log a follow-up lipid panel when you have the next lab result available.",
                }
            )
        if not recommendations:
            recommendations.append(
                {
                    "code": "maintain_heart_healthy_pattern",
                    "message": "Keep using the same activity and heart-healthy nutrition routine while lipid control stays stable.",
                }
            )
        return recommendations

    def _ldl_target(self, user_condition) -> float:
        profile = user_condition.profile_data or {}
        profile_target = self._numeric(profile.get("ldl_target"))
        if profile_target is not None:
            return profile_target

        rule = (
            ConditionRuleProfile.objects.filter(
                condition_type=user_condition.condition_type,
                rule_key="ldl_target",
                severity_code__in=("", user_condition.severity_code),
            )
            .order_by("-severity_code", "-id")
            .first()
        )
        rule_target = self._numeric(rule.rule_value if rule else None)
        return rule_target or 100
