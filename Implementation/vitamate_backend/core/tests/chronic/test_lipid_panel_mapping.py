from types import SimpleNamespace

from django.test import SimpleTestCase

from core.services.chronic.condition_indicator_service import ConditionIndicatorService
from core.services.chronic.lipid_panel_values import LipidPanelValues
from core.services.constraints.constraint_source_collector import ConstraintSourceCollector


class LipidPanelMappingRegressionTests(SimpleTestCase):
    @staticmethod
    def measurement(**overrides):
        values = {
            "indicator_name": "lipid_panel",
            "indicator_type": "lipid_panel",
            "value": 110,
            "value_1": 110,
            "value_2": 42,
            "value_3": 185,
            "payload": {},
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def test_lipid_panel_value_2_is_hdl_not_triglycerides(self):
        values = LipidPanelValues.from_measurement(self.measurement())

        self.assertEqual(values.hdl_mg_dl, 42)
        self.assertEqual(values.triglycerides_mg_dl, 185)
        self.assertEqual(
            ConstraintSourceCollector._indicator_metrics(self.measurement()),
            (("ldl", 110.0, "value_1"), ("hdl", 42.0, "value_2"), ("triglycerides", 185.0, "value_3")),
        )

    def test_missing_value_2_does_not_change_triglycerides(self):
        values = LipidPanelValues.from_measurement(self.measurement(value_2=None))

        self.assertIsNone(values.hdl_mg_dl)
        self.assertEqual(values.triglycerides_mg_dl, 185)

    def test_individual_lipid_fields_are_independent(self):
        ldl = LipidPanelValues.from_measurement(self.measurement(value_2=None, value_3=None))
        hdl = LipidPanelValues.from_measurement(
            self.measurement(value=42, value_1=None, value_2=42, value_3=None)
        )
        triglycerides = LipidPanelValues.from_measurement(
            self.measurement(value=185, value_1=None, value_2=None, value_3=185)
        )

        self.assertEqual(ldl.ldl_mg_dl, 110)
        self.assertEqual(hdl.hdl_mg_dl, 42)
        self.assertEqual(triglycerides.triglycerides_mg_dl, 185)

    def test_condition_indicator_service_uses_typed_accessor(self):
        measurement = self.measurement()

        self.assertEqual(
            ConditionIndicatorService._extract_metric_value(
                record=measurement,
                metric_key="hdl_cholesterol",
            ),
            42,
        )
        self.assertEqual(
            ConditionIndicatorService._extract_metric_value(
                record=measurement,
                metric_key="triglycerides",
            ),
            185,
        )
