from __future__ import annotations

from rest_framework import serializers

from core.models import (
    ConditionAlert,
    ConditionMedication,
    ConditionMedicationSchedule,
    ConditionRuleProfile,
    ConditionType,
    HealthIndicatorRecord,
    HealthRestriction,
    HealthTarget,
    UserCondition,
)
from core.services.condition_catalog_service import ConditionCatalogService


class HealthRestrictionSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthRestriction
        fields = [
            "id",
            "severity_code",
            "restriction_key",
            "title",
            "category",
            "metric_key",
            "evaluation_mode",
            "unit",
            "min_required_value",
            "max_allowed_value",
            "is_forbidden",
            "is_scored",
            "guidance",
            "evidence_source",
            "source_label",
            "source_version",
            "effective_date",
            "notes",
            "is_default",
            "is_inference",
        ]


class ConditionRuleProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConditionRuleProfile
        fields = [
            "id",
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


class ConditionTypeSerializer(serializers.ModelSerializer):
    restrictions = HealthRestrictionSerializer(many=True, read_only=True)
    rule_profiles = ConditionRuleProfileSerializer(many=True, read_only=True)

    class Meta:
        model = ConditionType
        fields = [
            "id",
            "code",
            "slug",
            "name",
            "display_name",
            "description",
            "is_supported",
            "sort_order",
            "setup_schema",
            "severity_options",
            "restrictions",
            "rule_profiles",
        ]


class SupportedConditionTypeSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    code = serializers.CharField()
    slug = serializers.CharField()
    name = serializers.CharField()
    display_name = serializers.CharField()
    description = serializers.CharField(allow_blank=True)
    can_add = serializers.BooleanField()
    is_active_for_user = serializers.BooleanField()
    severity_options = serializers.ListField(child=serializers.DictField(), default=list)
    setup_fields = serializers.ListField(child=serializers.DictField(), default=list)
    measurement_types = serializers.ListField(child=serializers.CharField(), default=list)
    supports_direct_daily_reading = serializers.BooleanField()


class HealthTargetSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthTarget
        fields = [
            "id",
            "target_key",
            "target_name",
            "category",
            "metric_key",
            "evaluation_mode",
            "unit",
            "min_value",
            "max_value",
            "status",
            "source_type",
            "priority",
            "is_scored",
            "guidance",
            "evidence_source",
            "is_inference",
            "last_evaluated_value",
            "last_evaluated_at",
        ]


class ConditionMedicationScheduleSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConditionMedicationSchedule
        fields = ["id", "time_of_day", "recurrence_days"]


class ConditionMedicationSerializer(serializers.ModelSerializer):
    schedules = ConditionMedicationScheduleSerializer(many=True)

    class Meta:
        model = ConditionMedication
        fields = [
            "id",
            "medicine",
            "display_name",
            "source_type",
            "name",
            "scientific_name",
            "dosage",
            "dosage_amount",
            "dosage_unit",
            "form",
            "instructions",
            "relation_to_meal",
            "recurrence_pattern",
            "start_date",
            "end_date",
            "is_active",
            "is_prn",
            "timezone",
            "adherence_mode",
            "reminder_enabled",
            "reminder_lead_minutes",
            "schedules",
        ]


class ConditionAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConditionAlert
        fields = [
            "id",
            "code",
            "level",
            "message",
            "alert_type",
            "metadata",
            "created_at",
            "status",
        ]


class HealthIndicatorRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthIndicatorRecord
        fields = [
            "id",
            "user_condition",
            "indicator_name",
            "indicator_type",
            "value",
            "value_1",
            "value_2",
            "value_3",
            "unit",
            "reading_context",
            "payload",
            "classification",
            "risk_level",
            "recorded_at",
        ]
        read_only_fields = ["classification", "risk_level"]

    def validate_user_condition(self, value):
        request = self.context.get("request")
        if request and value.user != request.user:
            raise serializers.ValidationError("You can only log indicators for your own conditions.")
        return value


class UserConditionWriteMedicationScheduleSerializer(serializers.Serializer):
    time_of_day = serializers.TimeField()
    recurrence_days = serializers.ListField(
        child=serializers.IntegerField(min_value=0, max_value=6),
        required=False,
        default=list,
    )


class UserConditionWriteMedicationSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=100)
    scientific_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    dosage = serializers.CharField(max_length=80)
    dosage_amount = serializers.CharField(max_length=40, required=False, allow_blank=True)
    dosage_unit = serializers.CharField(max_length=40, required=False, allow_blank=True)
    instructions = serializers.CharField(max_length=200, required=False, allow_blank=True)
    relation_to_meal = serializers.ChoiceField(
        choices=ConditionMedication.RELATION_CHOICES,
        default=ConditionMedication.RELATION_ANYTIME,
    )
    recurrence_pattern = serializers.ListField(
        child=serializers.IntegerField(min_value=0, max_value=6),
        required=False,
        default=list,
    )
    start_date = serializers.DateField(required=False, allow_null=True)
    end_date = serializers.DateField(required=False, allow_null=True)
    is_active = serializers.BooleanField(default=True)
    reminder_enabled = serializers.BooleanField(default=True)
    reminder_lead_minutes = serializers.IntegerField(required=False, min_value=0, default=15)
    schedules = UserConditionWriteMedicationScheduleSerializer(many=True)


class TargetOverrideSerializer(serializers.Serializer):
    target_key = serializers.CharField(max_length=80)
    target_name = serializers.CharField(max_length=120, required=False, allow_blank=True)
    category = serializers.CharField(max_length=20, required=False, allow_blank=True)
    metric_key = serializers.CharField(max_length=80, required=False, allow_blank=True)
    evaluation_mode = serializers.CharField(max_length=50, required=False, allow_blank=True)
    unit = serializers.CharField(max_length=30, required=False, allow_blank=True)
    min_value = serializers.FloatField(required=False, allow_null=True)
    max_value = serializers.FloatField(required=False, allow_null=True)
    source_type = serializers.ChoiceField(
        choices=HealthTarget.SOURCE_TYPE_CHOICES,
        default=HealthTarget.SOURCE_PHYSICIAN_OVERRIDE,
    )
    is_scored = serializers.BooleanField(required=False, default=False)
    guidance = serializers.CharField(required=False, allow_blank=True)
    evidence_source = serializers.CharField(required=False, allow_blank=True)


class UserConditionWriteSerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    condition_type = serializers.IntegerField(required=False)
    diagnosis_date = serializers.DateField(required=False, allow_null=True)
    status = serializers.ChoiceField(
        choices=UserCondition.STATUS_CHOICES,
        required=False,
    )
    severity_code = serializers.CharField(required=False, allow_blank=False)
    medications = UserConditionWriteMedicationSerializer(many=True, required=False)
    target_overrides = TargetOverrideSerializer(many=True, required=False)
    condition_status = serializers.ChoiceField(
        choices=UserCondition.STATUS_CHOICES,
        required=False,
        write_only=True,
    )
    severity = serializers.CharField(required=False, allow_blank=False, write_only=True)
    profile_data = serializers.JSONField(required=False)
    notes = serializers.CharField(required=False, allow_blank=True)
    is_active = serializers.BooleanField(required=False)

    def validate(self, attrs):
        condition_type_id = attrs.get("condition_type")
        severity_code = (
            attrs.get("severity_code")
            or attrs.get("severity")
            or getattr(self.instance, "severity_code", None)
        )
        if self.instance is None and condition_type_id is None:
            raise serializers.ValidationError({"condition_type": "This field is required."})
        if self.instance is not None and condition_type_id is not None:
            if condition_type_id != self.instance.condition_type_id:
                raise serializers.ValidationError(
                    {"condition_type": "condition_type cannot be changed after creation."}
                )
        if self.instance is None and not severity_code:
            raise serializers.ValidationError({"severity": "severity is required."})
        return attrs


class CreateUserConditionSerializer(UserConditionWriteSerializer):
    pass


class UpdateUserConditionSerializer(UserConditionWriteSerializer):
    pass


class ConditionMedicationWriteSerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    user_condition = serializers.IntegerField(required=False)
    display_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    source_type = serializers.ChoiceField(
        choices=ConditionMedication.SOURCE_TYPE_CHOICES,
        required=False,
    )
    name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    scientific_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    dosage = serializers.CharField(max_length=80, required=False, allow_blank=True)
    dosage_amount = serializers.CharField(max_length=40, required=False, allow_blank=True)
    dosage_unit = serializers.CharField(max_length=40, required=False, allow_blank=True)
    form = serializers.CharField(max_length=40, required=False, allow_blank=True)
    instructions = serializers.CharField(max_length=200, required=False, allow_blank=True)
    relation_to_meal = serializers.ChoiceField(
        choices=ConditionMedication.RELATION_CHOICES,
        required=False,
    )
    recurrence_pattern = serializers.ListField(
        child=serializers.IntegerField(min_value=0, max_value=6),
        required=False,
        default=list,
    )
    start_date = serializers.DateField(required=False, allow_null=True)
    end_date = serializers.DateField(required=False, allow_null=True)
    is_active = serializers.BooleanField(required=False)
    is_prn = serializers.BooleanField(required=False)
    timezone = serializers.CharField(max_length=64, required=False)
    adherence_mode = serializers.ChoiceField(
        choices=ConditionMedication.ADHERENCE_MODE_CHOICES,
        required=False,
    )
    reminder_enabled = serializers.BooleanField(required=False)
    reminder_lead_minutes = serializers.IntegerField(required=False, min_value=0)
    schedules = UserConditionWriteMedicationScheduleSerializer(many=True, required=False)

    def validate(self, attrs):
        user_condition_id = attrs.get("user_condition")
        if self.instance is None and user_condition_id is None:
            raise serializers.ValidationError({"user_condition": "This field is required."})
        return attrs


class ConditionDoseActionSerializer(serializers.Serializer):
    snooze_minutes = serializers.IntegerField(required=False, min_value=1, max_value=240)
    reason = serializers.CharField(required=False, allow_blank=True)


class ConditionReadingSerializer(serializers.Serializer):
    indicator_type = serializers.CharField(max_length=50)
    value = serializers.FloatField(required=False)
    reading_type = serializers.CharField(required=False, allow_blank=False)
    systolic = serializers.FloatField(required=False)
    diastolic = serializers.FloatField(required=False)
    pulse = serializers.FloatField(required=False)
    hdl = serializers.FloatField(required=False)
    triglycerides = serializers.FloatField(required=False)
    ldl = serializers.FloatField(required=False)
    total_cholesterol = serializers.FloatField(required=False)
    recorded_at = serializers.DateTimeField(required=False)

    def validate(self, attrs):
        indicator_type = attrs.get("indicator_type")
        if indicator_type == "glucose":
            if "value" not in attrs:
                raise serializers.ValidationError({"value": "value is required for glucose readings."})
            reading_type = str(attrs.get("reading_type", "")).strip().lower()
            if reading_type not in {"fasting", "before_meal", "after_meal", "bedtime"}:
                raise serializers.ValidationError(
                    {"reading_type": "reading_type must be fasting, before_meal, after_meal, or bedtime."}
                )
        elif indicator_type == "blood_pressure":
            missing = [field for field in ("systolic", "diastolic") if field not in attrs]
            if missing:
                raise serializers.ValidationError(
                    {field: f"{field} is required for blood pressure readings." for field in missing}
                )
        elif indicator_type == "lipid_panel":
            missing = [
                field
                for field in ("hdl", "triglycerides", "ldl", "total_cholesterol")
                if field not in attrs
            ]
            if missing:
                raise serializers.ValidationError(
                    {field: f"{field} is required for lipid panel readings." for field in missing}
                )
        else:
            raise serializers.ValidationError({"indicator_type": "Unsupported chronic reading type."})
        return attrs


class ConditionSummarySerializer(serializers.Serializer):
    condition_id = serializers.IntegerField()
    status = serializers.CharField()
    risk_flags = serializers.ListField(child=serializers.CharField(), default=list)
    latest_recorded_at = serializers.CharField(allow_null=True, required=False)
    recommendations = serializers.ListField(child=serializers.DictField(), default=list)
    tracker_impacts = serializers.ListField(child=serializers.DictField(), default=list)
    latest_reading = serializers.DictField(allow_null=True, required=False)
    alerts = serializers.ListField(child=serializers.DictField(), default=list)
    targets = serializers.ListField(child=serializers.DictField(), default=list)
