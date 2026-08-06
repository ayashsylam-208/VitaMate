from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class LipidPanelValues:
    """Canonical interpretation of HealthIndicatorRecord lipid fields.

    The persisted contract is value_1=LDL, value_2=HDL, and
    value_3=triglycerides. Payload values are compatibility fallbacks only.
    """

    ldl_mg_dl: float | None
    hdl_mg_dl: float | None
    triglycerides_mg_dl: float | None
    total_cholesterol_mg_dl: float | None = None

    @classmethod
    def from_measurement(cls, measurement) -> "LipidPanelValues":
        payload = dict(getattr(measurement, "payload", None) or {})
        indicator_name = str(getattr(measurement, "indicator_name", "") or "").strip().lower()
        generic_value = cls._number(getattr(measurement, "value", None))

        ldl = cls._number(getattr(measurement, "value_1", None))
        hdl = cls._number(getattr(measurement, "value_2", None))
        triglycerides = cls._number(getattr(measurement, "value_3", None))

        if ldl is None:
            ldl = cls._number(payload.get("ldl") or payload.get("ldl_cholesterol"))
        if hdl is None:
            hdl = cls._number(payload.get("hdl") or payload.get("hdl_cholesterol"))
        if triglycerides is None:
            triglycerides = cls._number(payload.get("triglycerides"))

        if indicator_name == "ldl_cholesterol" and ldl is None:
            ldl = generic_value
        elif indicator_name == "hdl_cholesterol" and hdl is None:
            hdl = generic_value
        elif indicator_name == "triglycerides" and triglycerides is None:
            triglycerides = generic_value

        return cls(
            ldl_mg_dl=ldl,
            hdl_mg_dl=hdl,
            triglycerides_mg_dl=triglycerides,
            total_cholesterol_mg_dl=cls._number(payload.get("total_cholesterol")),
        )

    @classmethod
    def from_input(cls, payload: dict) -> "LipidPanelValues":
        return cls(
            ldl_mg_dl=cls._number(payload.get("ldl")),
            hdl_mg_dl=cls._number(payload.get("hdl")),
            triglycerides_mg_dl=cls._number(payload.get("triglycerides")),
            total_cholesterol_mg_dl=cls._number(payload.get("total_cholesterol")),
        )

    @classmethod
    def from_legacy_metric(cls, *, metric_name: str, value) -> "LipidPanelValues":
        metric_name = str(metric_name or "").strip().lower()
        numeric = cls._number(value)
        return cls(
            ldl_mg_dl=numeric if metric_name == "ldl_cholesterol" else None,
            hdl_mg_dl=numeric if metric_name == "hdl_cholesterol" else None,
            triglycerides_mg_dl=numeric if metric_name == "triglycerides" else None,
        )

    def record_fields(self, *, recorded_at, reading_context: str = "followup") -> dict:
        return {
            "indicator_name": "lipid_panel",
            "indicator_type": "lipid_panel",
            "value": self.ldl_mg_dl or 0,
            "value_1": self.ldl_mg_dl,
            "value_2": self.hdl_mg_dl,
            "value_3": self.triglycerides_mg_dl,
            "unit": "mg/dL",
            "reading_context": reading_context,
            "payload": {
                "ldl": self.ldl_mg_dl,
                "hdl": self.hdl_mg_dl,
                "triglycerides": self.triglycerides_mg_dl,
                "total_cholesterol": self.total_cholesterol_mg_dl,
            },
            "recorded_at": recorded_at,
        }

    def metric_value(self, metric_key: str) -> float | None:
        metric_key = str(metric_key or "").strip().lower()
        if metric_key in {"ldl", "ldl_cholesterol"}:
            return self.ldl_mg_dl
        if metric_key in {"hdl", "hdl_cholesterol"}:
            return self.hdl_mg_dl
        if metric_key in {"triglyceride", "triglycerides"}:
            return self.triglycerides_mg_dl
        if metric_key == "total_cholesterol":
            return self.total_cholesterol_mg_dl
        return None

    def monitoring_metrics(self) -> tuple[tuple[str, float, str], ...]:
        values = (
            ("ldl", self.ldl_mg_dl, "value_1"),
            ("hdl", self.hdl_mg_dl, "value_2"),
            ("triglycerides", self.triglycerides_mg_dl, "value_3"),
        )
        return tuple((key, value, source_field) for key, value, source_field in values if value is not None)

    @staticmethod
    def _number(value) -> float | None:
        if value in (None, ""):
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None
