from __future__ import annotations

from django.utils import timezone

from core.services.condition_catalog_service import ConditionCatalogService


class ConditionIndicatorService:
    DIABETES_CONTEXTS = {"fasting", "before_meal", "after_meal", "bedtime"}
    CONDITION_MEASUREMENT_TYPES = {
        "diabetes": {"glucose"},
        "hypertension": {"blood_pressure"},
        "dyslipidemia": {"lipid_panel"},
    }

    @classmethod
    def validate_measurement_type(cls, *, user_condition, indicator_type: str) -> None:
        slug = ConditionCatalogService.canonical_slug(user_condition.condition_type)
        allowed = cls.CONDITION_MEASUREMENT_TYPES.get(slug, set())
        if indicator_type not in allowed:
            raise ValueError(f"Indicator type '{indicator_type}' is not valid for {slug}.")

    @classmethod
    def build_record_payload(cls, *, user_condition, payload: dict) -> dict:
        indicator_type = str(payload.get("indicator_type") or "").strip()
        cls.validate_measurement_type(user_condition=user_condition, indicator_type=indicator_type)

        recorded_at = payload.get("recorded_at") or timezone.now()
        slug = ConditionCatalogService.canonical_slug(user_condition.condition_type)

        if slug == "diabetes":
            reading_type = str(payload.get("reading_type") or "fasting").strip().lower()
            if reading_type not in cls.DIABETES_CONTEXTS:
                raise ValueError("reading_type must be one of fasting, before_meal, after_meal, bedtime.")
            value = cls._required_float(payload.get("value"), field_name="value")
            return {
                "indicator_name": "glucose" if reading_type == "fasting" else f"glucose_{reading_type}",
                "indicator_type": "glucose",
                "value": value,
                "value_1": value,
                "value_2": None,
                "value_3": None,
                "unit": "mg/dL",
                "reading_context": reading_type,
                "payload": {"value": value, "reading_type": reading_type},
                "recorded_at": recorded_at,
            }

        if slug == "hypertension":
            systolic = cls._required_float(payload.get("systolic"), field_name="systolic")
            diastolic = cls._required_float(payload.get("diastolic"), field_name="diastolic")
            pulse = cls._optional_float(payload.get("pulse"))
            return {
                "indicator_name": "blood_pressure",
                "indicator_type": "blood_pressure",
                "value": systolic,
                "value_1": systolic,
                "value_2": diastolic,
                "value_3": pulse,
                "unit": "mmHg",
                "reading_context": str(payload.get("reading_context") or "").strip(),
                "payload": {
                    "systolic": systolic,
                    "diastolic": diastolic,
                    "pulse": pulse,
                },
                "recorded_at": recorded_at,
            }

        hdl = cls._required_float(payload.get("hdl"), field_name="hdl")
        triglycerides = cls._required_float(payload.get("triglycerides"), field_name="triglycerides")
        ldl = cls._required_float(payload.get("ldl"), field_name="ldl")
        total_cholesterol = cls._required_float(
            payload.get("total_cholesterol"),
            field_name="total_cholesterol",
        )
        return {
            "indicator_name": "lipid_panel",
            "indicator_type": "lipid_panel",
            "value": ldl,
            "value_1": ldl,
            "value_2": hdl,
            "value_3": triglycerides,
            "unit": "mg/dL",
            "reading_context": str(payload.get("reading_context") or "followup").strip(),
            "payload": {
                "hdl": hdl,
                "triglycerides": triglycerides,
                "ldl": ldl,
                "total_cholesterol": total_cholesterol,
            },
            "recorded_at": recorded_at,
        }

    @classmethod
    def build_legacy_record_payload(cls, *, user_condition, payload: dict) -> dict:
        indicator_name = str(payload.get("indicator_name") or "").strip().lower()
        value = cls._required_float(payload.get("value"), field_name="value")
        recorded_at = payload.get("recorded_at") or timezone.now()

        if indicator_name in {"fasting_glucose", "glucose"}:
            return {
                "indicator_name": indicator_name,
                "indicator_type": "glucose",
                "value": value,
                "value_1": value,
                "value_2": None,
                "value_3": None,
                "unit": str(payload.get("unit") or "mg/dL"),
                "reading_context": "fasting",
                "payload": {"value": value, "reading_type": "fasting"},
                "recorded_at": recorded_at,
            }
        if indicator_name in {"blood_pressure_systolic", "blood_pressure_diastolic"}:
            return {
                "indicator_name": indicator_name,
                "indicator_type": "blood_pressure",
                "value": value,
                "value_1": value if indicator_name.endswith("systolic") else None,
                "value_2": value if indicator_name.endswith("diastolic") else None,
                "value_3": None,
                "unit": str(payload.get("unit") or "mmHg"),
                "reading_context": str(payload.get("reading_context") or "").strip(),
                "payload": {indicator_name: value},
                "recorded_at": recorded_at,
            }
        if indicator_name in {"ldl_cholesterol", "hdl_cholesterol", "triglycerides"}:
            return {
                "indicator_name": indicator_name,
                "indicator_type": "lipid_panel",
                "value": value,
                "value_1": value if indicator_name == "ldl_cholesterol" else None,
                "value_2": value if indicator_name == "hdl_cholesterol" else None,
                "value_3": value if indicator_name == "triglycerides" else None,
                "unit": str(payload.get("unit") or "mg/dL"),
                "reading_context": "followup",
                "payload": {indicator_name: value},
                "recorded_at": recorded_at,
            }
        return {
            "indicator_name": indicator_name,
            "indicator_type": indicator_name,
            "value": value,
            "value_1": value,
            "value_2": None,
            "value_3": None,
            "unit": str(payload.get("unit") or ""),
            "reading_context": str(payload.get("reading_context") or "").strip(),
            "payload": dict(payload.get("payload") or {}),
            "recorded_at": recorded_at,
        }

    @classmethod
    def latest_metric_value(cls, *, user_condition, metric_key: str) -> float | None:
        metric_key = str(metric_key).strip().lower()
        records = user_condition.indicator_records.order_by("-recorded_at", "-id")
        for record in records:
            value = cls._extract_metric_value(record=record, metric_key=metric_key)
            if value is not None:
                return value
        return None

    @classmethod
    def serialize_timeline(cls, *, user_condition) -> list[dict]:
        return [cls.serialize_record(record) for record in user_condition.indicator_records.order_by("-recorded_at", "-id")]

    @classmethod
    def serialize_record(cls, record) -> dict:
        payload = dict(record.payload or {})
        return {
            "id": record.id,
            "indicator_name": record.indicator_name,
            "indicator_type": record.indicator_type or record.indicator_name,
            "value": record.value,
            "value_1": record.value_1,
            "value_2": record.value_2,
            "value_3": record.value_3,
            "unit": record.unit,
            "reading_context": record.reading_context,
            "payload": payload,
            "classification": record.classification,
            "risk_level": record.risk_level,
            "recorded_at": record.recorded_at.isoformat() if record.recorded_at else None,
        }

    @classmethod
    def _extract_metric_value(cls, *, record, metric_key: str) -> float | None:
        payload = record.payload or {}
        if metric_key in {"glucose", "fasting_glucose"} and record.indicator_type == "glucose":
            if metric_key == "fasting_glucose" and record.reading_context not in {"", "fasting", "before_meal"}:
                return None
            return cls._optional_float(record.value_1 or record.value)
        if metric_key == "postprandial_glucose" and record.indicator_type == "glucose":
            if record.reading_context != "after_meal":
                return None
            return cls._optional_float(record.value_1 or record.value)
        if metric_key == "blood_pressure_systolic" and record.indicator_type == "blood_pressure":
            return cls._optional_float(record.value_1 or payload.get("systolic") or payload.get(metric_key))
        if metric_key == "blood_pressure_diastolic" and record.indicator_type == "blood_pressure":
            return cls._optional_float(record.value_2 or payload.get("diastolic") or payload.get(metric_key))
        if metric_key in {"ldl_cholesterol", "ldl"} and record.indicator_type == "lipid_panel":
            return cls._optional_float(payload.get("ldl") or record.value_1 or payload.get(metric_key))
        if metric_key in {"hdl_cholesterol", "hdl"} and record.indicator_type == "lipid_panel":
            return cls._optional_float(payload.get("hdl") or record.value_2 or payload.get(metric_key))
        if metric_key == "triglycerides" and record.indicator_type == "lipid_panel":
            return cls._optional_float(payload.get("triglycerides") or record.value_3 or payload.get(metric_key))
        if metric_key == "total_cholesterol" and record.indicator_type == "lipid_panel":
            return cls._optional_float(payload.get("total_cholesterol"))
        if record.indicator_name == metric_key:
            return cls._optional_float(record.value_1 or record.value)
        return None

    @staticmethod
    def _required_float(value, *, field_name: str) -> float:
        parsed = ConditionIndicatorService._optional_float(value)
        if parsed is None:
            raise ValueError(f"{field_name} is required.")
        return parsed

    @staticmethod
    def _optional_float(value) -> float | None:
        if value in (None, ""):
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None
