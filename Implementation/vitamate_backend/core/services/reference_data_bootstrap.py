from __future__ import annotations

from datetime import date

from django.db import transaction
from django.db.models import Q

from core.management.commands.rebuild_nutrition_catalog_v2 import CATEGORIES
from core.models import (
    ConditionRuleProfile,
    ConditionType,
    FoodCategory,
    HealthRestriction,
)


REFERENCE_DATE = date(2026, 4, 9)

SUPPORTED_CONDITION_TYPES = (
    {
        "code": "diabetes",
        "slug": "diabetes",
        "name": "Diabetes / Prediabetes",
        "display_name": "Diabetes",
        "sort_order": 1,
        "description": (
            "Structured diabetes care plan with medication reminders, hydration support, "
            "activity goals, and glucose-oriented tracking."
        ),
        "aliases": ("diabetes",),
        "setup_schema": {
            "setup_fields": [
                {
                    "key": "glucose_target",
                    "label": "Glucose target",
                    "type": "number",
                    "unit": "mg/dL",
                    "required": False,
                },
                {
                    "key": "hba1c_target",
                    "label": "HbA1c target",
                    "type": "number",
                    "unit": "%",
                    "required": False,
                },
            ],
            "measurement_types": ["glucose"],
            "supports_direct_daily_reading": True,
            "profile_defaults": {"glucose_target": 130, "hba1c_target": 7.0},
        },
        "severity_options": [
            {
                "code": "prediabetes",
                "label": "Prediabetes (fasting glucose 100-125 mg/dL or A1C 5.7-6.4%)",
                "description": "Use for higher-risk glucose states before diagnosed diabetes.",
            },
            {
                "code": "diabetes_managed",
                "label": "Diabetes (usual outpatient management)",
                "description": "For established diabetes under regular outpatient follow-up.",
            },
            {
                "code": "diabetes_intensive",
                "label": "Diabetes needing closer monitoring",
                "description": (
                    "Use when glucose control is unstable or treatment intensity is higher. "
                    "Confirm the detailed plan with the treating clinician."
                ),
            },
        ],
        "restrictions": [
            {
                "severity_code": "",
                "restriction_key": "activity_minutes_7d",
                "title": "Weekly moderate activity",
                "category": "activity",
                "metric_key": "activity_minutes_7d",
                "evaluation_mode": "rolling_7d_total",
                "unit": "minutes/week",
                "min_required_value": 150,
                "max_allowed_value": None,
                "is_scored": True,
                "guidance": "Aim for at least 150 minutes of moderate activity each week.",
                "evidence_source": "NIDDK Healthy Living with Diabetes, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "",
                "restriction_key": "fiber_per_1000_kcal",
                "title": "Dietary fiber density",
                "category": "nutrition",
                "metric_key": "fiber_per_1000_kcal",
                "evaluation_mode": "daily_ratio",
                "unit": "g/1000 kcal",
                "min_required_value": 14,
                "max_allowed_value": None,
                "is_scored": True,
                "guidance": "Prefer vegetables, legumes, fruit, and minimally processed whole grains.",
                "evidence_source": "American Diabetes Association patient nutrition education, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "",
                "restriction_key": "water_liters",
                "title": "Daily hydration floor",
                "category": "hydration",
                "metric_key": "water_liters",
                "evaluation_mode": "daily_total",
                "unit": "liters/day",
                "min_required_value": None,
                "max_allowed_value": None,
                "is_scored": True,
                "guidance": "Water is preferred for routine hydration; sports drinks are usually unnecessary for moderate exercise.",
                "evidence_source": "NIDDK Healthy Living with Diabetes, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "prediabetes",
                "restriction_key": "fasting_glucose",
                "title": "Fasting glucose goal",
                "category": "monitoring",
                "metric_key": "fasting_glucose",
                "evaluation_mode": "latest_indicator",
                "unit": "mg/dL",
                "min_required_value": None,
                "max_allowed_value": 99,
                "is_scored": False,
                "guidance": "Log fasting glucose manually when you have a reading available.",
                "evidence_source": "ADA diagnostic ranges for prediabetes, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "diabetes_managed",
                "restriction_key": "fasting_glucose",
                "title": "Pre-meal glucose goal",
                "category": "monitoring",
                "metric_key": "fasting_glucose",
                "evaluation_mode": "latest_indicator",
                "unit": "mg/dL",
                "min_required_value": 80,
                "max_allowed_value": 130,
                "is_scored": False,
                "guidance": "The app tracks the latest fasting or pre-meal glucose you enter.",
                "evidence_source": "ADA blood glucose targets for most nonpregnant adults, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "diabetes_intensive",
                "restriction_key": "fasting_glucose",
                "title": "Pre-meal glucose goal",
                "category": "monitoring",
                "metric_key": "fasting_glucose",
                "evaluation_mode": "latest_indicator",
                "unit": "mg/dL",
                "min_required_value": 80,
                "max_allowed_value": 130,
                "is_scored": False,
                "guidance": "Use this as a reference only unless your clinician gave a different target.",
                "evidence_source": "ADA blood glucose targets for most nonpregnant adults, accessed April 9, 2026",
                "is_inference": False,
            },
        ],
        "rule_profiles": {
            "": [
                {
                    "rule_key": "calorie_floor_ratio",
                    "rule_value": "0.85",
                    "rule_unit": "ratio",
                    "source_label": "American Diabetes Association / NIDDK",
                    "source_version": "2025-2026 patient guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Keep calorie reduction conservative for diabetes self-management.",
                },
                {
                    "rule_key": "water_floor_liters",
                    "rule_value": "2.0",
                    "rule_unit": "L/day",
                    "source_label": "NIDDK",
                    "source_version": "Healthy Living with Diabetes",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Water is preferred over sugar-sweetened beverages for routine hydration.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "ADA / NIDDK",
                    "source_version": "2025-2026 activity guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Regular moderate activity is preferred unless clinician advice differs.",
                },
                {
                    "rule_key": "avoid_sugary_drinks",
                    "rule_value": "true",
                    "rule_unit": "bool",
                    "source_label": "NIDDK",
                    "source_version": "Healthy Living with Diabetes",
                    "effective_date": REFERENCE_DATE,
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
                    "effective_date": REFERENCE_DATE,
                    "notes": "Reference target for prediabetes follow-up.",
                },
            ],
            "diabetes_managed": [
                {
                    "rule_key": "fasting_glucose_min",
                    "rule_value": "80",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Blood glucose targets for most nonpregnant adults",
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
                {
                    "rule_key": "fasting_glucose_max",
                    "rule_value": "130",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Blood glucose targets for most nonpregnant adults",
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
                {
                    "rule_key": "postprandial_glucose_max",
                    "rule_value": "180",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Post-meal glucose guidance",
                    "effective_date": REFERENCE_DATE,
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
                    "effective_date": REFERENCE_DATE,
                    "notes": "Use clinician overrides when available.",
                },
                {
                    "rule_key": "fasting_glucose_max",
                    "rule_value": "130",
                    "rule_unit": "mg/dL",
                    "source_label": "ADA",
                    "source_version": "Blood glucose targets for most nonpregnant adults",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Use clinician overrides when available.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "conservative",
                    "rule_unit": "",
                    "source_label": "ADA / NIDDK",
                    "source_version": "Safety-oriented activity guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Use a more conservative activity mode when diabetes needs closer monitoring.",
                },
            ],
        },
    },
    {
        "code": "hypertension",
        "slug": "hypertension",
        "name": "Hypertension / High Blood Pressure",
        "display_name": "Hypertension",
        "sort_order": 2,
        "description": (
            "Blood-pressure focused care plan with sodium limits, activity goals, "
            "potassium guidance, medication reminders, and pressure logging."
        ),
        "aliases": ("hypertension",),
        "setup_schema": {
            "setup_fields": [
                {
                    "key": "systolic_target",
                    "label": "Systolic target",
                    "type": "number",
                    "unit": "mm Hg",
                    "required": False,
                },
                {
                    "key": "diastolic_target",
                    "label": "Diastolic target",
                    "type": "number",
                    "unit": "mm Hg",
                    "required": False,
                },
                {
                    "key": "sodium_limit",
                    "label": "Sodium limit",
                    "type": "number",
                    "unit": "mg/day",
                    "required": False,
                },
            ],
            "measurement_types": ["blood_pressure"],
            "supports_direct_daily_reading": True,
            "profile_defaults": {
                "systolic_target": 129,
                "diastolic_target": 79,
                "sodium_limit": 1500,
            },
        },
        "severity_options": [
            {
                "code": "elevated",
                "label": "Elevated blood pressure (120-129 and <80 mm Hg)",
                "description": "Use before confirmed stage 1 hypertension.",
            },
            {
                "code": "stage_1",
                "label": "Stage 1 hypertension (130-139 or 80-89 mm Hg)",
                "description": "Use for established stage 1 high blood pressure.",
            },
            {
                "code": "stage_2",
                "label": "Stage 2 hypertension (>=140 or >=90 mm Hg)",
                "description": "Use for higher-risk blood pressure categories.",
            },
        ],
        "restrictions": [
            {
                "severity_code": "",
                "restriction_key": "activity_minutes_7d",
                "title": "Weekly moderate activity",
                "category": "activity",
                "metric_key": "activity_minutes_7d",
                "evaluation_mode": "rolling_7d_total",
                "unit": "minutes/week",
                "min_required_value": 150,
                "max_allowed_value": None,
                "is_scored": True,
                "guidance": "Spread activity across the week and move more, sit less.",
                "evidence_source": "NHLBI Heart-Healthy Living Get Regular Physical Activity, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "elevated",
                "restriction_key": "sodium_mg",
                "title": "Daily sodium ceiling",
                "category": "nutrition",
                "metric_key": "sodium_mg",
                "evaluation_mode": "daily_total",
                "unit": "mg/day",
                "min_required_value": None,
                "max_allowed_value": 2300,
                "is_scored": True,
                "guidance": "The AHA upper limit is 2,300 mg/day; lower is generally better for blood pressure.",
                "evidence_source": "American Heart Association sodium guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "stage_1",
                "restriction_key": "sodium_mg",
                "title": "Daily sodium ceiling",
                "category": "nutrition",
                "metric_key": "sodium_mg",
                "evaluation_mode": "daily_total",
                "unit": "mg/day",
                "min_required_value": None,
                "max_allowed_value": 1500,
                "is_scored": True,
                "guidance": "Use the AHA optimal goal when possible and review with your clinician.",
                "evidence_source": "American Heart Association sodium guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "stage_2",
                "restriction_key": "sodium_mg",
                "title": "Daily sodium ceiling",
                "category": "nutrition",
                "metric_key": "sodium_mg",
                "evaluation_mode": "daily_total",
                "unit": "mg/day",
                "min_required_value": None,
                "max_allowed_value": 1500,
                "is_scored": True,
                "guidance": "Use the AHA optimal goal when possible and review with your clinician.",
                "evidence_source": "American Heart Association sodium guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "",
                "restriction_key": "potassium_mg",
                "title": "Dietary potassium support",
                "category": "nutrition",
                "metric_key": "potassium_mg",
                "evaluation_mode": "daily_total",
                "unit": "mg/day",
                "min_required_value": 3510,
                "max_allowed_value": None,
                "is_scored": False,
                "guidance": (
                    "Only increase potassium if kidney function and medications allow it. "
                    "This is advisory, not scored."
                ),
                "evidence_source": "WHO potassium intake guideline and AHA potassium guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "",
                "restriction_key": "blood_pressure_systolic",
                "title": "Systolic blood pressure log",
                "category": "monitoring",
                "metric_key": "blood_pressure_systolic",
                "evaluation_mode": "latest_indicator",
                "unit": "mm Hg",
                "min_required_value": None,
                "max_allowed_value": 129,
                "is_scored": False,
                "guidance": "Record your latest systolic reading manually.",
                "evidence_source": "AHA blood pressure categories and treatment guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "",
                "restriction_key": "blood_pressure_diastolic",
                "title": "Diastolic blood pressure log",
                "category": "monitoring",
                "metric_key": "blood_pressure_diastolic",
                "evaluation_mode": "latest_indicator",
                "unit": "mm Hg",
                "min_required_value": None,
                "max_allowed_value": 79,
                "is_scored": False,
                "guidance": "Record your latest diastolic reading manually.",
                "evidence_source": "AHA blood pressure categories and treatment guidance, accessed April 9, 2026",
                "is_inference": False,
            },
        ],
        "rule_profiles": {
            "": [
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Heart-healthy living guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Encourage regular moderate activity and avoid aggressive intensity escalation.",
                },
            ],
            "elevated": [
                {
                    "rule_key": "sodium_limit_mg",
                    "rule_value": "2300",
                    "rule_unit": "mg/day",
                    "source_label": "American Heart Association",
                    "source_version": "Sodium guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
                {
                    "rule_key": "bp_systolic_max",
                    "rule_value": "129",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
                {
                    "rule_key": "bp_diastolic_max",
                    "rule_value": "79",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": REFERENCE_DATE,
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
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
                {
                    "rule_key": "bp_systolic_max",
                    "rule_value": "129",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
                {
                    "rule_key": "bp_diastolic_max",
                    "rule_value": "79",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": REFERENCE_DATE,
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
                    "effective_date": REFERENCE_DATE,
                    "notes": "Prefer the stricter sodium ceiling when multiple conditions are active.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "conservative",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Heart-healthy living guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Use a safer exercise mode for higher-risk blood pressure categories.",
                },
                {
                    "rule_key": "bp_systolic_max",
                    "rule_value": "129",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
                {
                    "rule_key": "bp_diastolic_max",
                    "rule_value": "79",
                    "rule_unit": "mm Hg",
                    "source_label": "American Heart Association",
                    "source_version": "Blood pressure categories",
                    "effective_date": REFERENCE_DATE,
                    "notes": "",
                },
            ],
        },
    },
    {
        "code": "hyperlipidemia",
        "slug": "dyslipidemia",
        "name": "High Cholesterol / Hyperlipidemia",
        "display_name": "Dyslipidemia",
        "sort_order": 3,
        "description": (
            "Lipid-focused care plan with saturated-fat limits, trans-fat avoidance, "
            "fiber guidance, activity goals, and medication reminders."
        ),
        "aliases": ("hyperlipidemia", "dyslipidemia"),
        "setup_schema": {
            "setup_fields": [
                {
                    "key": "hdl_target",
                    "label": "HDL target",
                    "type": "number",
                    "unit": "mg/dL",
                    "required": False,
                },
                {
                    "key": "triglyceride_target",
                    "label": "Triglycerides target",
                    "type": "number",
                    "unit": "mg/dL",
                    "required": False,
                },
                {
                    "key": "followup_interval_days",
                    "label": "Follow-up interval",
                    "type": "number",
                    "unit": "days",
                    "required": False,
                },
            ],
            "measurement_types": ["lipid_panel"],
            "supports_direct_daily_reading": False,
            "aliases": ["hyperlipidemia"],
            "profile_defaults": {
                "hdl_target": 40,
                "triglyceride_target": 150,
                "followup_interval_days": 90,
            },
        },
        "severity_options": [
            {
                "code": "borderline_high_ldl",
                "label": "Borderline high LDL (130-159 mg/dL)",
                "description": "Use when LDL is above optimal but not yet in the high range.",
            },
            {
                "code": "high_ldl",
                "label": "High LDL (160-189 mg/dL)",
                "description": "Use for clearly elevated LDL cholesterol.",
            },
            {
                "code": "very_high_ldl",
                "label": "Very high LDL (>=190 mg/dL)",
                "description": "Use when LDL is in a high-risk range and clinician follow-up is essential.",
            },
        ],
        "restrictions": [
            {
                "severity_code": "",
                "restriction_key": "activity_minutes_7d",
                "title": "Weekly moderate activity",
                "category": "activity",
                "metric_key": "activity_minutes_7d",
                "evaluation_mode": "rolling_7d_total",
                "unit": "minutes/week",
                "min_required_value": 150,
                "max_allowed_value": None,
                "is_scored": True,
                "guidance": "Regular activity helps improve LDL, HDL, blood pressure, and weight.",
                "evidence_source": "NHLBI physical activity guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "borderline_high_ldl",
                "restriction_key": "saturated_fat_pct_kcal",
                "title": "Saturated fat share",
                "category": "nutrition",
                "metric_key": "saturated_fat_pct_kcal",
                "evaluation_mode": "daily_ratio",
                "unit": "% kcal",
                "min_required_value": None,
                "max_allowed_value": 7,
                "is_scored": True,
                "guidance": "Keep saturated fat low as part of a heart-healthy diet.",
                "evidence_source": "NHLBI TLC diet and AHA saturated fat guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "high_ldl",
                "restriction_key": "saturated_fat_pct_kcal",
                "title": "Saturated fat share",
                "category": "nutrition",
                "metric_key": "saturated_fat_pct_kcal",
                "evaluation_mode": "daily_ratio",
                "unit": "% kcal",
                "min_required_value": None,
                "max_allowed_value": 6,
                "is_scored": True,
                "guidance": "Aim for less than 6% of calories from saturated fat.",
                "evidence_source": "American Heart Association saturated fat guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "very_high_ldl",
                "restriction_key": "saturated_fat_pct_kcal",
                "title": "Saturated fat share",
                "category": "nutrition",
                "metric_key": "saturated_fat_pct_kcal",
                "evaluation_mode": "daily_ratio",
                "unit": "% kcal",
                "min_required_value": None,
                "max_allowed_value": 6,
                "is_scored": True,
                "guidance": "Aim for less than 6% of calories from saturated fat.",
                "evidence_source": "American Heart Association saturated fat guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "",
                "restriction_key": "trans_fat_g",
                "title": "Trans fat avoidance",
                "category": "nutrition",
                "metric_key": "trans_fat_g",
                "evaluation_mode": "daily_total",
                "unit": "g/day",
                "min_required_value": None,
                "max_allowed_value": 0,
                "is_scored": True,
                "guidance": "Avoid trans fat when possible; even small amounts add LDL risk.",
                "evidence_source": "American Heart Association fats guidance, accessed April 9, 2026",
                "is_inference": False,
            },
            {
                "severity_code": "",
                "restriction_key": "fiber_g",
                "title": "Fiber support for LDL lowering",
                "category": "nutrition",
                "metric_key": "fiber_g",
                "evaluation_mode": "daily_total",
                "unit": "g/day",
                "min_required_value": 10,
                "max_allowed_value": None,
                "is_scored": False,
                "guidance": "TLC recommends soluble fiber; the app currently tracks total fiber as a practical proxy.",
                "evidence_source": "NHLBI TLC guide soluble-fiber recommendation, accessed April 9, 2026",
                "is_inference": True,
            },
            {
                "severity_code": "",
                "restriction_key": "cholesterol_mg",
                "title": "Dietary cholesterol limit",
                "category": "nutrition",
                "metric_key": "cholesterol_mg",
                "evaluation_mode": "daily_total",
                "unit": "mg/day",
                "min_required_value": None,
                "max_allowed_value": 200,
                "is_scored": False,
                "guidance": "Use as supportive guidance alongside saturated-fat reduction.",
                "evidence_source": "NHLBI TLC diet, accessed April 9, 2026",
                "is_inference": False,
            },
        ],
        "rule_profiles": {
            "": [
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Physical activity guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Regular moderate activity supports LDL lowering.",
                },
            ],
            "borderline_high_ldl": [
                {
                    "rule_key": "ldl_target",
                    "rule_value": "130",
                    "rule_unit": "mg/dL",
                    "source_label": "ACC / AHA lipid guidance",
                    "source_version": "Clinical reference target",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Use as a default reference target unless clinician override exists.",
                },
            ],
            "high_ldl": [
                {
                    "rule_key": "ldl_target",
                    "rule_value": "100",
                    "rule_unit": "mg/dL",
                    "source_label": "ACC / AHA lipid guidance",
                    "source_version": "Clinical reference target",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Prefer LDL-focused targets over HDL or triglycerides alone.",
                },
            ],
            "very_high_ldl": [
                {
                    "rule_key": "ldl_target",
                    "rule_value": "70",
                    "rule_unit": "mg/dL",
                    "source_label": "ACC / AHA lipid guidance",
                    "source_version": "Higher-risk reference target",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Use clinician override when a different target is prescribed.",
                },
                {
                    "rule_key": "exercise_intensity_mode",
                    "rule_value": "moderate",
                    "rule_unit": "",
                    "source_label": "NHLBI / AHA",
                    "source_version": "Physical activity guidance",
                    "effective_date": REFERENCE_DATE,
                    "notes": "Encourage consistency instead of overly aggressive intensity.",
                },
            ],
        },
    },
)

EXPECTED_RESTRICTION_COUNT = sum(len(item["restrictions"]) for item in SUPPORTED_CONDITION_TYPES)
EXPECTED_RULE_PROFILE_COUNT = sum(
    len(rows)
    for item in SUPPORTED_CONDITION_TYPES
    for rows in item["rule_profiles"].values()
)
EXPECTED_CATEGORY_COUNT = len(CATEGORIES)


def _has_minimum_reference_data() -> bool:
    supported_count = ConditionType.objects.filter(
        slug__in=["diabetes", "hypertension", "dyslipidemia"],
        is_supported=True,
    ).count()
    if supported_count != 3:
        return False
    if FoodCategory.objects.filter(code__in=[code for code, _name, _sort_order in CATEGORIES]).count() != EXPECTED_CATEGORY_COUNT:
        return False
    if HealthRestriction.objects.filter(condition_type__slug__in=["diabetes", "hypertension", "dyslipidemia"]).count() < EXPECTED_RESTRICTION_COUNT:
        return False
    if ConditionRuleProfile.objects.filter(condition_type__slug__in=["diabetes", "hypertension", "dyslipidemia"]).count() < EXPECTED_RULE_PROFILE_COUNT:
        return False
    return True


def _ensure_food_categories() -> None:
    for code, name, sort_order in CATEGORIES:
        FoodCategory.objects.update_or_create(
            code=code,
            defaults={
                "name": name,
                "sort_order": sort_order,
                "is_active": True,
            },
        )


def _resolve_condition_type(config: dict) -> ConditionType | None:
    aliases = tuple(dict.fromkeys(config["aliases"] + (config["code"], config["slug"])))
    return (
        ConditionType.objects.filter(Q(code__in=aliases) | Q(slug__in=aliases))
        .order_by("id")
        .first()
    )


def _ensure_condition_type(config: dict) -> ConditionType:
    condition_type = _resolve_condition_type(config)
    defaults = {
        "code": config["code"],
        "slug": config["slug"],
        "name": config["name"],
        "display_name": config["display_name"],
        "description": config["description"],
        "is_supported": True,
        "sort_order": config["sort_order"],
        "setup_schema": config["setup_schema"],
        "severity_options": config["severity_options"],
    }
    if condition_type is None:
        return ConditionType.objects.create(**defaults)

    for field, value in defaults.items():
        setattr(condition_type, field, value)
    condition_type.save(
        update_fields=[
            "code",
            "slug",
            "name",
            "display_name",
            "description",
            "is_supported",
            "sort_order",
            "setup_schema",
            "severity_options",
        ]
    )
    return condition_type


def _sync_restrictions(*, condition_type: ConditionType, restrictions: list[dict]) -> None:
    expected = {(item["severity_code"], item["restriction_key"]): item for item in restrictions}
    existing = {
        (item.severity_code, item.restriction_key): item
        for item in HealthRestriction.objects.filter(condition_type=condition_type)
    }
    for key, payload in expected.items():
        restriction = existing.get(key)
        defaults = dict(payload)
        if restriction is None:
            HealthRestriction.objects.create(condition_type=condition_type, **defaults)
            continue
        for field, value in defaults.items():
            setattr(restriction, field, value)
        restriction.save(
            update_fields=[
                "severity_code",
                "restriction_key",
                "title",
                "category",
                "metric_key",
                "evaluation_mode",
                "unit",
                "min_required_value",
                "max_allowed_value",
                "is_scored",
                "guidance",
                "evidence_source",
                "is_inference",
            ]
        )
    for key, restriction in existing.items():
        if key not in expected:
            restriction.delete()


def _sync_rule_profiles(*, condition_type: ConditionType, rule_profiles: dict[str, list[dict]]) -> None:
    expected = {}
    for severity_code, rows in rule_profiles.items():
        for row in rows:
            expected[(severity_code, row["rule_key"])] = row

    existing = {
        (item.severity_code, item.rule_key): item
        for item in ConditionRuleProfile.objects.filter(condition_type=condition_type)
    }
    for key, payload in expected.items():
        severity_code, rule_key = key
        profile = existing.get(key)
        defaults = {
            "severity_code": severity_code,
            "rule_key": rule_key,
            "rule_value": payload["rule_value"],
            "rule_unit": payload["rule_unit"],
            "source_label": payload["source_label"],
            "source_version": payload["source_version"],
            "effective_date": payload["effective_date"],
            "notes": payload["notes"],
            "is_default": True,
        }
        if profile is None:
            ConditionRuleProfile.objects.create(
                condition_type=condition_type,
                **defaults,
            )
            continue
        for field, value in defaults.items():
            setattr(profile, field, value)
        profile.save(
            update_fields=[
                "severity_code",
                "rule_key",
                "rule_value",
                "rule_unit",
                "source_label",
                "source_version",
                "effective_date",
                "notes",
                "is_default",
            ]
        )
    for key, profile in existing.items():
        if key not in expected:
            profile.delete()


@transaction.atomic
def ensure_reference_data() -> None:
    if _has_minimum_reference_data():
        return

    _ensure_food_categories()
    for config in SUPPORTED_CONDITION_TYPES:
        condition_type = _ensure_condition_type(config)
        _sync_restrictions(
            condition_type=condition_type,
            restrictions=config["restrictions"],
        )
        _sync_rule_profiles(
            condition_type=condition_type,
            rule_profiles=config["rule_profiles"],
        )
