from django.db import migrations


def seed_catalog(apps, schema_editor):
    ConditionType = apps.get_model("core", "ConditionType")
    HealthRestriction = apps.get_model("core", "HealthRestriction")

    catalog = [
        {
            "code": "diabetes",
            "name": "Diabetes / Prediabetes",
            "description": (
                "Structured diabetes care plan with medication reminders, hydration support, "
                "activity goals, and glucose-oriented tracking."
            ),
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
        },
        {
            "code": "hypertension",
            "name": "Hypertension / High Blood Pressure",
            "description": (
                "Blood-pressure focused care plan with sodium limits, activity goals, "
                "potassium guidance, medication reminders, and pressure logging."
            ),
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
        },
        {
            "code": "hyperlipidemia",
            "name": "High Cholesterol / Hyperlipidemia",
            "description": (
                "Lipid-focused care plan with saturated-fat limits, trans-fat avoidance, "
                "fiber guidance, activity goals, and medication reminders."
            ),
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
                    "guidance": (
                        "TLC recommends soluble fiber; the app currently tracks total fiber as a practical proxy."
                    ),
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
        },
    ]

    for item in catalog:
        condition_type, _ = ConditionType.objects.update_or_create(
            code=item["code"],
            defaults={
                "name": item["name"],
                "description": item["description"],
                "severity_options": item["severity_options"],
            },
        )
        HealthRestriction.objects.filter(condition_type=condition_type).delete()
        for restriction in item["restrictions"]:
            HealthRestriction.objects.create(condition_type=condition_type, **restriction)


def unseed_catalog(apps, schema_editor):
    ConditionType = apps.get_model("core", "ConditionType")
    ConditionType.objects.filter(code__in=["diabetes", "hypertension", "hyperlipidemia"]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0004_conditionmedication_conditiontype_and_more"),
    ]

    operations = [
        migrations.RunPython(seed_catalog, unseed_catalog),
    ]
