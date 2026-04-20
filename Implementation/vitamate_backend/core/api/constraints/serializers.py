from rest_framework import serializers

from core.models import ConstraintResolutionRun, ResolvedTrackerConstraint


class ResolvedTrackerConstraintSerializer(serializers.ModelSerializer):
    class Meta:
        model = ResolvedTrackerConstraint
        fields = [
            "id",
            "tracker_type",
            "category",
            "metric_key",
            "rule_type",
            "evaluation_mode",
            "unit",
            "min_value",
            "max_value",
            "target_value",
            "warning_value",
            "priority",
            "is_blocking",
            "is_scored",
            "source_type",
            "source_condition",
            "source_restriction",
            "source_target",
            "source_nutrient_rule",
            "source_user_nutrient_target",
            "reason_summary",
            "confidence_score",
            "effective_from",
            "effective_to",
            "computed_at",
            "status",
            "version_hash",
        ]


class ConstraintResolutionRunSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConstraintResolutionRun
        fields = [
            "id",
            "trigger_type",
            "trigger_reference",
            "input_signature",
            "run_status",
            "total_constraints_generated",
            "total_constraints_superseded",
            "started_at",
            "completed_at",
            "error_message",
        ]


class ConstraintRecomputeSerializer(serializers.Serializer):
    trigger_type = serializers.ChoiceField(
        choices=[choice[0] for choice in ConstraintResolutionRun.TRIGGER_CHOICES],
        default=ConstraintResolutionRun.TRIGGER_MANUAL,
        required=False,
    )
    trigger_reference = serializers.CharField(required=False, allow_blank=True, default="")
    tracker_type = serializers.ChoiceField(
        choices=[choice[0] for choice in ResolvedTrackerConstraint.TRACKER_TYPE_CHOICES],
        required=False,
        allow_null=True,
    )
