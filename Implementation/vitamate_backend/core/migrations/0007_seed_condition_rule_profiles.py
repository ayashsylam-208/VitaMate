from datetime import date

from django.db import migrations


def seed_rule_profiles(apps, schema_editor):
    ConditionType = apps.get_model("core", "ConditionType")
    ConditionRuleProfile = apps.get_model("core", "ConditionRuleProfile")

    catalog = {
        "diabetes": {
            "": [
                {
                    "rule_key": "calorie_floor_ratio",
                    "rule_value": "0.85",
                    "rule_unit": "ratio",
                    "source_label": "American Diabetes Association / NIDDK",
                    "source_version": "2025-2026 patient guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Keep calorie reduction conservative for diabetes self-management.",
                },
                {
                    "rule_key": "water_floor_liters",
                    "rule_value": "2.0",
                    "rule_unit": "L/day",
                    "source_label": "NIDDK",
                    "source_version": "Healthy Living with Diabetes",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Water is preferred over sugar-sweetened beverages for routine hydration.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "ADA / NIDDK",
                    "source_version": "2025-2026 activity guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Regular moderate activity is preferred unless clinician advice differs.",
                },
                {
                    "rule_key": "avoid_sugary_drinks",
                    "rule_value": "true",
                    "rule_unit": "bool",
                    "source_label": "NIDDK",
                    "source_version": "Healthy Living with Diabetes",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Used as a soft behavioral rule in recommendations and summaries.",
                },
            ],
            "prediabetes": [
                {
                    "rule_key": "fasting_glucose_max",
                    "rule_value": "99",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Prediabetes diagnostic range reference",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Reference target for prediabetes follow-up.",
                }
            ],
            "diabetes_managed": [
                {
                    "rule_key": "fasting_glucose_min",
                    "rule_value": "80",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Blood glucose targets for most nonpregnant adults",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
                {
                    "rule_key": "fasting_glucose_max",
                    "rule_value": "130",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Blood glucose targets for most nonpregnant adults",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
                {
                    "rule_key": "postprandial_glucose_max",
                    "rule_value": "180",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Post-meal glucose guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
            ],
            "diabetes_intensive": [
                {
                    "rule_key": "fasting_glucose_min",
                    "rule_value": "80",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Blood glucose targets for most nonpregnant adults",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Use clinician overrides when available.",
                },
                {
                    "rule_key": "fasting_glucose_max",
                    "rule_value": "130",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Blood glucose targets for most nonpregnant adults",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Use clinician overrides when available.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "conservative",
                    "rule_unit": "",
                    "source_label": "ADA / NIDDK",
                    "source_version": "Safety-oriented activity guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Use a more conservative activity mode when diabetes needs closer monitoring.",
                },
            ],
        },
        "hypertension": {
            "": [
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Heart-healthy living guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Encourage regular moderate activity and avoid aggressive intensity escalation.",
                }
            ],
            "elevated": [
                {
                    "rule_key": "sodium_limit_mg",
                    "rule_value": "2300",
                    "rule_unit": "mg/day",
                    "source_label": "American Heart Association",
                    "source_version": "Sodium guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
                {
                    "rule_key": "bp_systolic_max",
                    "rule_value": "129",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
                {
                    "rule_key": "bp_diastolic_max",
                    "rule_value": "79",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
            ],
            "stage_1": [
                {
                    "rule_key": "sodium_limit_mg",
                    "rule_value": "1500",
                    "rule_unit": "mg/day",
                    "source_label": "American Heart Association",
                    "source_version": "Sodium guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
                {
                    "rule_key": "bp_systolic_max",
                    "rule_value": "129",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
                {
                    "rule_key": "bp_diastolic_max",
                    "rule_value": "79",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
            ],
            "stage_2": [
                {
                    "rule_key": "sodium_limit_mg",
                    "rule_value": "1500",
                    "rule_unit": "mg/day",
                    "source_label": "American Heart Association",
                    "source_version": "Sodium guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Prefer the stricter sodium ceiling when multiple conditions are active.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "conservative",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Heart-healthy living guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Use a safer exercise mode for higher-risk blood pressure categories.",
                },
                {
                    "rule_key": "bp_systolic_max",
                    "rule_value": "129",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
                {
                    "rule_key": "bp_diastolic_max",
                    "rule_value": "79",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": date(2026, 4, 9),
                    "notes": "",
                },
            ],
        },
        "hyperlipidemia": {
            "": [
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Physical activity guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Regular moderate activity supports LDL lowering.",
                }
            ],
            "borderline_high_ldl": [
                {
                    "rule_key": "ldl_target",
                    "rule_value": "130",
                    "rule_unit": "mg/dL",
                    "source_label": "ACC / AHA lipid guidance",
                    "source_version": "Clinical reference target",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Use as a default reference target unless clinician override exists.",
                }
            ],
            "high_ldl": [
                {
                    "rule_key": "ldl_target",
                    "rule_value": "100",
                    "rule_unit": "mg/dL",
                    "source_label": "ACC / AHA lipid guidance",
                    "source_version": "Clinical reference target",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Prefer LDL-focused targets over HDL or triglycerides alone.",
                }
            ],
            "very_high_ldl": [
                {
                    "rule_key": "ldl_target",
                    "rule_value": "70",
                    "rule_unit": "mg/dL",
                    "source_label": "ACC / AHA lipid guidance",
                    "source_version": "Higher-risk reference target",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Use clinician override when a different target is prescribed.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Physical activity guidance",
                    "effective_date": date(2026, 4, 9),
                    "notes": "Encourage consistency instead of overly aggressive intensity.",
                },
            ],
        },
    }

    ConditionRuleProfile.objects.all().delete()
    for condition_code, severities in catalog.items():
        condition_type = ConditionType.objects.get(code=condition_code)
        for severity_code, rules in severities.items():
            for rule in rules:
                ConditionRuleProfile.objects.create(
                    condition_type=condition_type,
                    severity_code=severity_code,
                    is_default=True,
                    **rule,
                )


def unseed_rule_profiles(apps, schema_editor):
    ConditionRuleProfile = apps.get_model("core", "ConditionRuleProfile")
    ConditionRuleProfile.objects.all().delete()


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0006_expand_chronic_condition_models"),
    ]

    operations = [
        migrations.RunPython(seed_rule_profiles, unseed_rule_profiles),
    ]
