from __future__ import annotations

import hashlib
import logging
from io import BytesIO
from datetime import timedelta
from decimal import Decimal

from django.core.files.uploadedfile import SimpleUploadedFile
from django.conf import settings
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from PIL import Image, ImageOps, UnidentifiedImageError
from rest_framework.exceptions import NotFound, ValidationError

from ai_meals.gateway import AIMealGateway, AIServiceError
from ai_meals.models import (
    AIIngredientMapping,
    MealAnalysisCandidate,
    MealAnalysisComponent,
    MealAnalysisSession,
)
from core.models import FoodItem, FoodItemAlias, MealLog, normalize_food_search_text
from core.repositories.food_item_repository import NutritionCatalogRepository
from core.services.nutrition.meal_finalization_service import MealFinalizationService


logger = logging.getLogger(__name__)


class MealAnalysisConflict(ValidationError):
    status_code = 409
    default_code = "conflict"


class MealImageValidator:
    CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}

    @classmethod
    def prepare(cls, uploaded_file):
        if uploaded_file.size <= 0:
            raise ValidationError({"image": "The image is empty."})
        if uploaded_file.size > settings.AI_MEALS_MAX_IMAGE_BYTES:
            raise ValidationError({"image": "The image exceeds the 10 MB limit."})
        content_type = str(getattr(uploaded_file, "content_type", "") or "").lower()
        if content_type not in cls.CONTENT_TYPES:
            raise ValidationError({"image": "Use a JPEG, PNG, or WebP image."})

        header = uploaded_file.read(16)
        uploaded_file.seek(0)
        is_jpeg = header.startswith(b"\xff\xd8\xff")
        is_png = header.startswith(b"\x89PNG\r\n\x1a\n")
        is_webp = header.startswith(b"RIFF") and header[8:12] == b"WEBP"
        if not (is_jpeg or is_png or is_webp):
            raise ValidationError({"image": "The file content is not a supported image."})

        try:
            with Image.open(uploaded_file) as source:
                source.verify()
            uploaded_file.seek(0)
            with Image.open(uploaded_file) as source:
                width, height = source.size
                if width < settings.AI_MEALS_MIN_IMAGE_DIMENSION or height < settings.AI_MEALS_MIN_IMAGE_DIMENSION:
                    raise ValidationError(
                        {"image": "The image is too small for reliable meal analysis."}
                    )
                if width > settings.AI_MEALS_MAX_IMAGE_DIMENSION or height > settings.AI_MEALS_MAX_IMAGE_DIMENSION:
                    raise ValidationError(
                        {"image": "The image dimensions exceed the supported limit."}
                    )
                if width * height > settings.AI_MEALS_MAX_IMAGE_PIXELS:
                    raise ValidationError(
                        {"image": "The image contains too many pixels."}
                    )
                normalized = ImageOps.exif_transpose(source)
                if normalized.mode not in {"RGB", "L"}:
                    background = Image.new("RGB", normalized.size, "white")
                    if "A" in normalized.getbands():
                        background.paste(normalized, mask=normalized.getchannel("A"))
                    else:
                        background.paste(normalized)
                    normalized = background
                elif normalized.mode == "L":
                    normalized = normalized.convert("RGB")
                output = BytesIO()
                normalized.save(output, format="JPEG", quality=90, optimize=True)
        except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
            raise ValidationError({"image": "The image could not be decoded safely."}) from exc
        finally:
            uploaded_file.seek(0)

        content = output.getvalue()
        if len(content) > settings.AI_MEALS_MAX_IMAGE_BYTES:
            raise ValidationError({"image": "The normalized image exceeds the size limit."})
        digest = hashlib.sha256(content).hexdigest()
        return (
            SimpleUploadedFile(
                "meal-analysis.jpg",
                content,
                content_type="image/jpeg",
            ),
            digest,
        )


class IngredientMappingService:
    DEFAULT_PROVIDER = "vitamate_ai"

    @classmethod
    def resolve(cls, *, user, provider_id, label, provider=DEFAULT_PROVIDER):
        normalized = normalize_food_search_text(label)
        mappings = AIIngredientMapping.objects.filter(
            is_active=True,
            provider=provider,
        ).select_related("food_item")
        mapping = None
        if provider_id:
            mapping = mappings.filter(provider_id=provider_id).first()
        if mapping is None and normalized:
            mapping = mappings.filter(normalized_label=normalized).first()
        if (
            mapping is not None
            and mapping.food_item.is_active
            and mapping.food_item.created_by_id in {None, user.id}
        ):
            return mapping.food_item

        accessible = NutritionCatalogRepository.accessible_to_user(
            user=user,
            include_inactive=False,
        )
        food = accessible.filter(normalized_name=normalized).order_by(
            "created_by_id",
            "-is_verified",
            "id",
        ).first()
        if food is not None:
            return food
        alias_food_id = (
            FoodItemAlias.objects.filter(
                normalized_alias=normalized,
                food_item__in=accessible,
            )
            .order_by("food_item__created_by_id", "-food_item__is_verified", "id")
            .values_list("food_item_id", flat=True)
            .first()
        )
        return accessible.filter(id=alias_food_id).first() if alias_food_id else None


class MealAnalysisService:
    def __init__(self, gateway=None):
        self.gateway = gateway or AIMealGateway()

    def analyze(
        self,
        *,
        user,
        image,
        auto_weight_mode="try",
        dishware_profile_id=None,
        plate_diameter_cm=None,
        analysis_key="",
    ):
        analysis_key = str(analysis_key or "").strip()
        if analysis_key:
            existing = MealAnalysisSession.objects.filter(
                user=user,
                analysis_key=analysis_key,
            ).first()
            if existing is not None:
                return existing
        image, image_hash = MealImageValidator.prepare(image)
        session = MealAnalysisSession.objects.create(
            user=user,
            image=image,
            image_sha256=image_hash,
            analysis_key=analysis_key,
            status=MealAnalysisSession.STATUS_ANALYZING,
            expires_at=timezone.now()
            + timedelta(minutes=settings.AI_MEALS_SESSION_TTL_MINUTES),
        )
        try:
            session.image.open("rb")
            payload = self.gateway.analyze(
                image_file=session.image.file,
                filename=session.image.name.rsplit("/", 1)[-1],
                content_type=getattr(image, "content_type", "image/jpeg"),
                auto_weight_mode=auto_weight_mode,
                dishware_profile_id=dishware_profile_id,
                plate_diameter_cm=plate_diameter_cm,
            )
        except AIServiceError as exc:
            session.status = MealAnalysisSession.STATUS_FAILED
            session.failure_code = exc.code
            session.failure_message = str(exc)
            session.save(
                update_fields=(
                    "status",
                    "failure_code",
                    "failure_message",
                    "updated_at",
                )
            )
            exc.analysis_id = session.id
            raise
        finally:
            if session.image:
                session.image.close()

        try:
            self._persist_provider_result(session=session, payload=payload)
        except Exception as exc:
            logger.exception(
                "Failed to persist AI meal analysis result.",
                extra={"analysis_id": str(session.id), "user_id": user.id},
            )
            session.status = MealAnalysisSession.STATUS_FAILED
            session.failure_code = "analysis_persistence_failure"
            session.failure_message = "The meal analysis result could not be saved."
            session.save(
                update_fields=(
                    "status",
                    "failure_code",
                    "failure_message",
                    "updated_at",
                )
            )
            error = AIServiceError(
                session.failure_message,
                code=session.failure_code,
            )
            error.analysis_id = session.id
            raise error from exc
        return session

    @transaction.atomic
    def confirm(self, *, user, analysis_id, payload):
        session = self._locked_session(user=user, analysis_id=analysis_id)
        self._assert_mutable(session)
        provider_allows_manual_weight = bool(
            session.raw_analysis.get("manual_weight_allowed", False)
        )
        if not session.finalize_allowed and not provider_allows_manual_weight:
            decision_code = str(session.decision_code or "").lower()
            if decision_code not in {"review_required", "needs_weight", "manual_weight_required"}:
                raise MealAnalysisConflict(
                    "The image quality is not sufficient. Retake the meal photo."
                )
        accessible = NutritionCatalogRepository.accessible_to_user(
            user=user,
            include_inactive=False,
        )
        existing = {item.id: item for item in session.components.all()}
        if existing:
            # Free the active ordering range before compacting a user-selected
            # subset. Updating a later component to position zero directly can
            # otherwise collide with an excluded component still at zero.
            session.components.update(sort_order=F("sort_order") + len(existing))
        included_count = 0
        seen_ids = set()
        for index, value in enumerate(payload["components"]):
            food = accessible.filter(id=value["food_item_id"]).first()
            if food is None:
                raise ValidationError(
                    {"components": f"Food item {value['food_item_id']} is not accessible."}
                )
            component_id = value.get("id")
            component = existing.get(component_id) if component_id else None
            if component_id and component is None:
                raise ValidationError({"components": "A component does not belong to this analysis."})
            if component is None:
                component = MealAnalysisComponent(session=session)
            component.provider_id = value.get("provider_id", component.provider_id)
            component.provider_label = (
                value.get("provider_label") or component.provider_label or food.name
            )
            component.mapped_food_item = food
            component.confirmed_grams = Decimal(str(value["confirmed_grams"]))
            component.is_included = value.get("is_included", True)
            component.is_user_confirmed = True
            component.sort_order = index
            component.save()
            seen_ids.add(component.id)
            included_count += int(component.is_included)

        session.components.exclude(id__in=seen_ids).update(is_included=False)
        if included_count == 0:
            raise ValidationError({"components": "At least one component must be included."})
        session.selected_dish_id = payload.get("selected_dish_id", "")
        session.selected_dish_label = payload["selected_dish_label"].strip()
        session.meal_type = payload["meal_type"]
        session.consumed_at = payload.get("consumed_at") or timezone.now()
        session.status = MealAnalysisSession.STATUS_READY
        session.finalize_allowed = True
        session.save(
            update_fields=(
                "selected_dish_id",
                "selected_dish_label",
                "meal_type",
                "consumed_at",
                "status",
                "finalize_allowed",
                "updated_at",
            )
        )
        return session

    @transaction.atomic
    def finalize(self, *, user, analysis_id, idempotency_key, notes=""):
        session = self._locked_session(user=user, analysis_id=analysis_id)
        if session.status == MealAnalysisSession.STATUS_FINALIZED:
            if session.finalization_key == idempotency_key and session.finalized_meal_id:
                return session, session.finalized_meal, True
            raise MealAnalysisConflict("This analysis has already been finalized.")
        self._assert_mutable(session)
        if session.status != MealAnalysisSession.STATUS_READY:
            raise ValidationError({"status": "Confirm all meal components before finalizing."})

        components = list(
            session.components.filter(is_included=True)
            .select_related("mapped_food_item__nutrition_facts")
            .order_by("sort_order", "id")
        )
        if not components:
            raise ValidationError({"components": "No included components were found."})
        invalid = [
            component.id
            for component in components
            if not component.is_user_confirmed
            or component.mapped_food_item_id is None
            or component.confirmed_grams is None
        ]
        if invalid:
            raise ValidationError({"components": f"Unconfirmed component ids: {invalid}"})

        digest = hashlib.sha256(
            f"{session.id}:{idempotency_key}".encode("utf-8")
        ).hexdigest()
        meal = MealFinalizationService.finalize(
            user=user,
            meal_type=session.meal_type,
            display_name=session.selected_dish_label,
            components=[
                {
                    "food": component.mapped_food_item,
                    "quantity_grams": float(component.confirmed_grams),
                    "confidence_score": component.confidence_score,
                    "source_label": component.provider_label,
                    "is_user_confirmed": True,
                }
                for component in components
            ],
            consumed_at=session.consumed_at,
            notes=notes,
            source=MealLog.SOURCE_AI,
            correlation_id=str(session.id),
            source_ref=f"ai-analysis:{session.id}",
            quality_tags=["ai_confirmed"],
            finalization_key=f"ai:{digest}",
        )
        session.finalization_key = idempotency_key
        session.finalized_meal = meal
        session.status = MealAnalysisSession.STATUS_FINALIZED
        session.save(
            update_fields=(
                "finalization_key",
                "finalized_meal",
                "status",
                "updated_at",
            )
        )
        return session, meal, False

    @staticmethod
    def get_for_user(*, user, analysis_id):
        session = (
            MealAnalysisSession.objects.filter(user=user, id=analysis_id)
            .prefetch_related(
                "candidates__mapped_food_item__nutrition_facts",
                "components__mapped_food_item__nutrition_facts",
            )
            .select_related("finalized_meal")
            .first()
        )
        if session is None:
            raise NotFound("Meal analysis was not found.")
        if session.is_expired and session.status not in {
            MealAnalysisSession.STATUS_FINALIZED,
            MealAnalysisSession.STATUS_EXPIRED,
        }:
            session.status = MealAnalysisSession.STATUS_EXPIRED
            session.save(update_fields=("status", "updated_at"))
        return session

    @staticmethod
    def _locked_session(*, user, analysis_id):
        session = (
            MealAnalysisSession.objects.select_for_update()
            .filter(user=user, id=analysis_id)
            .first()
        )
        if session is None:
            raise NotFound("Meal analysis was not found.")
        return session

    @staticmethod
    def _assert_mutable(session):
        if session.is_expired:
            session.status = MealAnalysisSession.STATUS_EXPIRED
            session.save(update_fields=("status", "updated_at"))
            raise MealAnalysisConflict("This meal analysis has expired. Retake the photo.")
        if session.status == MealAnalysisSession.STATUS_FAILED:
            raise MealAnalysisConflict("This meal analysis failed. Retake the photo.")

    def _persist_provider_result(self, *, session, payload):
        session.provider_session_id = str(payload.get("analysis_session_id") or "")
        session.provider_status = str(payload.get("status") or "")
        session.decision_code = str(payload.get("decision_code") or "")
        session.finalize_allowed = bool(payload.get("finalize_allowed", False))
        session.required_user_inputs = payload.get("required_user_inputs") or []
        session.raw_analysis = payload
        session.model_versions = payload.get("model_versions") or {}
        weight = payload.get("estimated_weight_g")
        session.estimated_weight_grams = Decimal(str(weight)) if weight else None

        dishes = self._dish_candidates(payload)
        ingredients = self._ingredient_candidates(payload)
        if dishes:
            session.selected_dish_id = dishes[0]["provider_id"]
            session.selected_dish_label = dishes[0]["label"]

        candidate_rows = []
        for kind, values in (
            (MealAnalysisCandidate.KIND_DISH, dishes),
            (MealAnalysisCandidate.KIND_INGREDIENT, ingredients),
        ):
            for rank, value in enumerate(values[:8]):
                mapped = IngredientMappingService.resolve(
                    user=session.user,
                    provider_id=value["provider_id"],
                    label=value["label"],
                )
                candidate_rows.append(
                    MealAnalysisCandidate(
                        session=session,
                        kind=kind,
                        provider_id=value["provider_id"],
                        label=value["label"],
                        display_name_ar=value["display_name_ar"],
                        confidence_score=value["confidence"],
                        rank=rank,
                        mapped_food_item=mapped,
                        raw_payload=value["raw"],
                    )
                )
        MealAnalysisCandidate.objects.bulk_create(candidate_rows)

        component_rows = []
        percentages = [value["percentage"] for value in ingredients]
        use_percentages = bool(percentages) and all(value is not None for value in percentages)
        total_percentage = sum(float(value or 0) for value in percentages)
        total_weight = float(session.estimated_weight_grams) if session.estimated_weight_grams is not None else None
        weight_allocations = self._component_weight_allocations(
            total_weight=total_weight,
            percentages=[
                (
                    float(value["percentage"]) / total_percentage
                    if use_percentages and total_percentage > 0
                    else 1 / max(len(ingredients), 1)
                )
                for value in ingredients
            ],
        )
        for index, value in enumerate(ingredients):
            percentage = (
                float(value["percentage"]) / total_percentage
                if use_percentages and total_percentage > 0
                else 1 / max(len(ingredients), 1)
            )
            mapped = IngredientMappingService.resolve(
                user=session.user,
                provider_id=value["provider_id"],
                label=value["label"],
            )
            suggested_grams = weight_allocations[index] if weight_allocations else None
            component_rows.append(
                MealAnalysisComponent(
                    session=session,
                    provider_id=value["provider_id"],
                    provider_label=value["label"],
                    mapped_food_item=mapped,
                    confidence_score=value["confidence"],
                    suggested_percentage=percentage,
                    suggested_grams=suggested_grams,
                    confirmed_grams=suggested_grams,
                    is_included=True,
                    is_user_confirmed=False,
                    sort_order=index,
                    raw_payload=value["raw"],
                )
            )
        MealAnalysisComponent.objects.bulk_create(component_rows)
        has_unmapped = any(row.mapped_food_item_id is None for row in component_rows)
        has_weight = all(row.suggested_grams is not None for row in component_rows)
        if not component_rows or has_unmapped or not has_weight:
            session.status = MealAnalysisSession.STATUS_NEEDS_INPUT
        else:
            session.status = MealAnalysisSession.STATUS_REVIEW
        session.save()

    @staticmethod
    def _component_weight_allocations(*, total_weight, percentages):
        if total_weight is None or total_weight <= 0 or not percentages:
            return None
        basis = [max(float(value or 0), 0) for value in percentages]
        basis_sum = sum(basis)
        if basis_sum <= 0:
            basis = [1.0 for _ in percentages]
            basis_sum = float(len(percentages))
        allocations = []
        remaining = round(float(total_weight), 2)
        for index, value in enumerate(basis):
            if index == len(basis) - 1:
                grams = max(0.01, remaining)
            else:
                grams = round(float(total_weight) * (value / basis_sum), 2)
                remaining = round(remaining - grams, 2)
            allocations.append(grams)
        return allocations

    @staticmethod
    def _dish_candidates(payload):
        values = (payload.get("dish_recognition") or {}).get("top_k") or payload.get(
            "dish_top_k"
        ) or []
        return [MealAnalysisService._candidate(value, dish=True) for value in values]

    @staticmethod
    def _ingredient_candidates(payload):
        values = payload.get("suggested_ingredients") or (
            payload.get("ingredient_suggestions") or {}
        ).get("items") or []
        return [MealAnalysisService._candidate(value, dish=False) for value in values]

    @staticmethod
    def _candidate(value, *, dish):
        return {
            "provider_id": str(
                value.get("canonical_dish_id" if dish else "ingredient_id") or ""
            ),
            "label": str(
                value.get("display_name_en")
                or value.get("name")
                or value.get("label")
                or "Unknown"
            ),
            "display_name_ar": str(value.get("display_name_ar") or ""),
            "confidence": value.get("score", value.get("confidence")),
            "percentage": value.get("default_percentage"),
            "raw": value,
        }
