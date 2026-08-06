import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

from core.models import FoodItem, MealLog, normalize_food_search_text


def analysis_image_upload_path(instance, filename):
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else "jpg"
    return f"ai_meals/user_{instance.user_id}/{uuid.uuid4().hex}.{extension}"


class MealAnalysisSession(models.Model):
    STATUS_UPLOADED = "uploaded"
    STATUS_ANALYZING = "analyzing"
    STATUS_REVIEW = "review"
    STATUS_NEEDS_INPUT = "needs_input"
    STATUS_READY = "ready_to_finalize"
    STATUS_FAILED = "failed"
    STATUS_FINALIZED = "finalized"
    STATUS_EXPIRED = "expired"
    STATUS_CHOICES = [
        (STATUS_UPLOADED, "Uploaded"),
        (STATUS_ANALYZING, "Analyzing"),
        (STATUS_REVIEW, "Review"),
        (STATUS_NEEDS_INPUT, "Needs input"),
        (STATUS_READY, "Ready to finalize"),
        (STATUS_FAILED, "Failed"),
        (STATUS_FINALIZED, "Finalized"),
        (STATUS_EXPIRED, "Expired"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="meal_analysis_sessions",
    )
    image = models.FileField(upload_to=analysis_image_upload_path)
    image_sha256 = models.CharField(max_length=64, db_index=True)
    analysis_key = models.CharField(max_length=120, blank=True, default="")
    status = models.CharField(
        max_length=24,
        choices=STATUS_CHOICES,
        default=STATUS_UPLOADED,
        db_index=True,
    )
    provider_session_id = models.CharField(max_length=120, blank=True, default="")
    provider_status = models.CharField(max_length=40, blank=True, default="")
    decision_code = models.CharField(max_length=80, blank=True, default="")
    finalize_allowed = models.BooleanField(default=False)
    required_user_inputs = models.JSONField(default=list, blank=True)
    raw_analysis = models.JSONField(default=dict, blank=True)
    model_versions = models.JSONField(default=dict, blank=True)
    selected_dish_id = models.CharField(max_length=120, blank=True, default="")
    selected_dish_label = models.CharField(max_length=160, blank=True, default="")
    estimated_weight_grams = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
    )
    meal_type = models.CharField(
        max_length=20,
        choices=MealLog.MEAL_TYPES,
        default="unknown",
    )
    consumed_at = models.DateTimeField(null=True, blank=True)
    finalization_key = models.CharField(max_length=120, blank=True, default="")
    finalized_meal = models.OneToOneField(
        MealLog,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ai_analysis_session",
    )
    failure_code = models.CharField(max_length=80, blank=True, default="")
    failure_message = models.TextField(blank=True, default="")
    expires_at = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("user", "status", "created_at"), name="ai_meal_user_status_idx"),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=("user", "analysis_key"),
                condition=~models.Q(analysis_key=""),
                name="unique_user_ai_analysis_key",
            ),
        ]

    @property
    def is_expired(self):
        return self.expires_at <= timezone.now()


class MealAnalysisCandidate(models.Model):
    KIND_DISH = "dish"
    KIND_INGREDIENT = "ingredient"
    KIND_CHOICES = [(KIND_DISH, "Dish"), (KIND_INGREDIENT, "Ingredient")]

    session = models.ForeignKey(
        MealAnalysisSession,
        on_delete=models.CASCADE,
        related_name="candidates",
    )
    kind = models.CharField(max_length=20, choices=KIND_CHOICES)
    provider_id = models.CharField(max_length=120, blank=True, default="")
    label = models.CharField(max_length=160)
    display_name_ar = models.CharField(max_length=160, blank=True, default="")
    confidence_score = models.DecimalField(max_digits=6, decimal_places=5, null=True, blank=True)
    rank = models.PositiveSmallIntegerField(default=0)
    mapped_food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ai_analysis_candidates",
    )
    raw_payload = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ("kind", "rank", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("session", "kind", "rank"),
                name="unique_ai_candidate_rank",
            ),
        ]


class AIIngredientMapping(models.Model):
    provider = models.CharField(max_length=40, default="vitamate_ai", db_index=True)
    provider_id = models.CharField(max_length=120, blank=True, default="", db_index=True)
    provider_label = models.CharField(max_length=160)
    normalized_label = models.CharField(max_length=180, db_index=True)
    aliases = models.JSONField(default=list, blank=True)
    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.PROTECT,
        related_name="ai_ingredient_mappings",
    )
    mapping_confidence = models.DecimalField(max_digits=5, decimal_places=4, default=1)
    is_active = models.BooleanField(default=True, db_index=True)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verified_ai_ingredient_mappings",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("normalized_label", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("provider", "provider_id"),
                condition=models.Q(is_active=True) & ~models.Q(provider_id=""),
                name="unique_active_ai_provider_ingredient",
            ),
            models.UniqueConstraint(
                fields=("provider", "normalized_label"),
                condition=models.Q(is_active=True, provider_id=""),
                name="unique_active_ai_provider_label",
            ),
        ]

    def save(self, *args, **kwargs):
        self.normalized_label = normalize_food_search_text(self.provider_label)
        super().save(*args, **kwargs)


class MealAnalysisComponent(models.Model):
    session = models.ForeignKey(
        MealAnalysisSession,
        on_delete=models.CASCADE,
        related_name="components",
    )
    provider_id = models.CharField(max_length=120, blank=True, default="")
    provider_label = models.CharField(max_length=160)
    mapped_food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ai_analysis_components",
    )
    confidence_score = models.DecimalField(max_digits=6, decimal_places=5, null=True, blank=True)
    suggested_percentage = models.DecimalField(max_digits=6, decimal_places=5, null=True, blank=True)
    suggested_grams = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    confirmed_grams = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    is_included = models.BooleanField(default=True)
    is_user_confirmed = models.BooleanField(default=False)
    sort_order = models.PositiveSmallIntegerField(default=0)
    raw_payload = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ("sort_order", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("session", "sort_order"),
                name="unique_ai_component_order",
            ),
            models.CheckConstraint(
                condition=(
                    models.Q(confirmed_grams__isnull=True)
                    | models.Q(confirmed_grams__gt=0)
                ),
                name="ai_component_confirmed_grams_positive",
            ),
        ]
