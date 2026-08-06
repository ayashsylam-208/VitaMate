from unittest.mock import patch
from io import BytesIO
from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection
from django.db.models import Sum
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from ai_meals.gateway import AIServiceError
from ai_meals.models import AIIngredientMapping, MealAnalysisSession
from core.models import IntegrationOutboxEvent, MealLog, MealLogComponent
from gamification.models import PointsTransaction
from test_utils.helpers import create_food_item, create_user_with_profile


def provider_payload():
    return {
        "status": "ok",
        "decision_code": "review_required",
        "analysis_session_id": "provider-session-1",
        "finalize_allowed": True,
        "required_user_inputs": [],
        "estimated_weight_g": 300,
        "model_versions": {
            "dish": "test-v1",
            "ingredient": "test-v1",
            "auto_weight_mode": "try",
        },
        "weight_status": "ok",
        "weight_message": None,
        "dish_recognition": {
            "top_k": [
                {
                    "canonical_dish_id": "chicken_rice",
                    "display_name_en": "Chicken with rice",
                    "display_name_ar": "",
                    "score": 0.91,
                }
            ]
        },
        "suggested_ingredients": [
            {
                "ingredient_id": "rice",
                "name": "Rice",
                "confidence": 0.9,
                "default_percentage": 0.6,
            },
            {
                "ingredient_id": "chicken",
                "name": "Chicken",
                "confidence": 0.8,
                "default_percentage": 0.4,
            },
        ],
        "mask_preview": {
            "overlay_png_base64": "dGVzdA==",
            "crop_png_base64": None,
            "width": 64,
            "height": 64,
        },
        "user_message": "Confirm the dish and portions.",
    }


def valid_png():
    output = BytesIO()
    Image.new("RGB", (256, 256), "white").save(output, format="PNG")
    return SimpleUploadedFile(
        "meal.png",
        output.getvalue(),
        content_type="image/png",
    )


class AIMealApiTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="ai-meal-user")
        self.other_user = create_user_with_profile(username="ai-meal-other")
        self.client.force_authenticate(self.user)
        self.rice = create_food_item(
            name="Rice",
            calories_100g=130,
            carbs_100g=28,
            protein_100g=2,
            fat_100g=0,
        )
        self.chicken = create_food_item(
            name="Chicken",
            calories_100g=200,
            carbs_100g=0,
            protein_100g=30,
            fat_100g=4,
        )

    @patch("ai_meals.gateway.AIMealGateway.analyze", return_value=provider_payload())
    def test_analysis_requires_confirmation_then_finalizes_once(self, gateway):
        analyze = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png(), "auto_weight_mode": "try"},
            format="multipart",
        )
        self.assertEqual(analyze.status_code, status.HTTP_201_CREATED)
        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 0)
        analysis = analyze.data["data"]
        self.assertEqual(analysis["status"], MealAnalysisSession.STATUS_REVIEW)
        self.assertEqual(len(analysis["components"]), 2)
        self.assertEqual(float(analysis["components"][0]["suggested_grams"]), 180.0)
        self.assertEqual(float(analysis["components"][1]["suggested_grams"]), 120.0)
        self.assertEqual(
            analysis["components"][0]["mapped_food_nutrition_100g"]["calories_kcal"],
            130.0,
        )
        self.assertEqual(analysis["weight_status"], "ok")
        self.assertTrue(analysis["weight_estimation_attempted"])
        gateway.assert_called_once()

        confirmation = self.client.patch(
            f"/api/nutrition/ai-meals/{analysis['id']}/",
            {
                "selected_dish_id": "chicken_rice",
                "selected_dish_label": "Chicken rice bowl",
                "meal_type": "lunch",
                "components": [
                    {
                        "id": analysis["components"][0]["id"],
                        "food_item_id": self.rice.id,
                        "confirmed_grams": 180,
                    },
                    {
                        "id": analysis["components"][1]["id"],
                        "food_item_id": self.chicken.id,
                        "confirmed_grams": 120,
                    },
                ],
            },
            format="json",
        )
        self.assertEqual(confirmation.status_code, status.HTTP_200_OK)
        self.assertEqual(confirmation.data["data"]["status"], "ready_to_finalize")

        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 0)

        with CaptureQueriesContext(connection) as queries:
            finalize = self.client.post(
                f"/api/nutrition/ai-meals/{analysis['id']}/finalize/",
                {"notes": "User confirmed"},
                format="json",
                HTTP_IDEMPOTENCY_KEY="mobile-request-0001",
            )
        self.assertEqual(finalize.status_code, status.HTTP_201_CREATED)
        self.assertLessEqual(len(queries), 50)
        self.assertFalse(finalize.data["data"]["already_finalized"])
        self.assertGreater(finalize.data["data"]["points_delta"], 0)
        self.assertIn("nutrition_summary", finalize.data["data"])
        self.assertIn("hydration_delta_ml", finalize.data["data"])
        self.assertIn("habit_events", finalize.data["data"])
        self.assertIn("today_summary", finalize.data["data"])
        meal_id = finalize.data["data"]["meal"]["id"]
        meal = MealLog.objects.get(id=meal_id)
        self.assertTrue(meal.is_composite)
        self.assertEqual(meal.source, MealLog.SOURCE_AI)
        self.assertEqual(meal.display_name, "Chicken rice bowl")
        self.assertEqual(meal.components.count(), 2)
        self.assertEqual(meal.total_calories, 474)
        points_count = PointsTransaction.objects.filter(user=self.user).count()
        self.assertEqual(
            IntegrationOutboxEvent.objects.filter(user=self.user).count(),
            1,
        )

        retry = self.client.post(
            f"/api/nutrition/ai-meals/{analysis['id']}/finalize/",
            {},
            format="json",
            HTTP_IDEMPOTENCY_KEY="mobile-request-0001",
        )
        self.assertEqual(retry.status_code, status.HTTP_201_CREATED)
        self.assertEqual(retry.data["data"]["meal"]["id"], meal_id)
        self.assertTrue(retry.data["data"]["already_finalized"])
        self.assertEqual(retry.data["data"]["points_delta"], 0)
        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(
            PointsTransaction.objects.filter(user=self.user).count(),
            points_count,
        )
        self.assertEqual(
            IntegrationOutboxEvent.objects.filter(user=self.user).count(),
            1,
        )

        conflict = self.client.post(
            f"/api/nutrition/ai-meals/{analysis['id']}/finalize/",
            {},
            format="json",
            HTTP_IDEMPOTENCY_KEY="different-request",
        )
        self.assertEqual(conflict.status_code, status.HTTP_409_CONFLICT)

        delete = self.client.delete(f"/api/meals/{meal_id}/")
        self.assertEqual(delete.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(MealLog.objects.filter(id=meal_id).exists())
        self.assertFalse(MealLogComponent.objects.filter(meal_log_id=meal_id).exists())
        nutrition_points = (
            PointsTransaction.objects.filter(
                user=self.user,
                source_type=PointsTransaction.SOURCE_NUTRITION,
            ).aggregate(total=Sum("points"))["total"]
            or 0
        )
        self.assertEqual(nutrition_points, 0)

    @patch("ai_meals.gateway.AIMealGateway.analyze", return_value=provider_payload())
    def test_confirmation_can_keep_only_a_later_suggested_component(self, gateway):
        analyze = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png(), "auto_weight_mode": "try"},
            format="multipart",
        )
        analysis = analyze.data["data"]
        chicken_component = analysis["components"][1]

        confirmation = self.client.patch(
            f"/api/nutrition/ai-meals/{analysis['id']}/confirmation/",
            {
                "selected_dish_id": "chicken_rice",
                "selected_dish_label": "Chicken",
                "meal_type": "lunch",
                "components": [
                    {
                        "id": chicken_component["id"],
                        "food_item_id": self.chicken.id,
                        "confirmed_grams": 120,
                    }
                ],
            },
            format="json",
        )

        self.assertEqual(confirmation.status_code, status.HTTP_200_OK)
        included = confirmation.data["data"]["components"]
        self.assertEqual(sum(item["is_included"] for item in included), 1)
        self.assertEqual(
            next(item for item in included if item["is_included"])["mapped_food_item"],
            self.chicken.id,
        )

    @patch("ai_meals.gateway.AIMealGateway.analyze")
    def test_analysis_requires_manual_weights_when_auto_weight_fails(self, gateway):
        payload = provider_payload()
        payload["estimated_weight_g"] = None
        payload["weight_status"] = "missing_scale_reference"
        payload["weight_message"] = "Enter the total meal weight manually."
        payload["model_versions"]["auto_weight_mode"] = "try"
        gateway.return_value = payload

        analyze = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
        )

        self.assertEqual(analyze.status_code, status.HTTP_201_CREATED)
        analysis = analyze.data["data"]
        self.assertEqual(analysis["status"], MealAnalysisSession.STATUS_NEEDS_INPUT)
        self.assertIsNone(analysis["estimated_weight_grams"])
        self.assertEqual(analysis["weight_status"], "missing_scale_reference")
        self.assertEqual(
            analysis["weight_message"],
            "Enter the total meal weight manually.",
        )
        self.assertTrue(analysis["weight_estimation_attempted"])
        self.assertTrue(
            all(item["suggested_grams"] is None for item in analysis["components"])
        )

    @patch("ai_meals.gateway.AIMealGateway.analyze", return_value=provider_payload())
    def test_analysis_is_owner_scoped(self, gateway):
        analyze = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
        )
        analysis_id = analyze.data["data"]["id"]
        self.client.force_authenticate(self.other_user)

        self.assertEqual(
            self.client.get(f"/api/nutrition/ai-meals/{analysis_id}/").status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.assertEqual(
            self.client.patch(
                f"/api/nutrition/ai-meals/{analysis_id}/",
                {
                    "selected_dish_label": "Other meal",
                    "meal_type": "lunch",
                    "components": [
                        {
                            "food_item_id": self.rice.id,
                            "confirmed_grams": 100,
                        }
                    ],
                },
                format="json",
            ).status_code,
            status.HTTP_404_NOT_FOUND,
        )

    @patch("ai_meals.gateway.AIMealGateway.analyze", return_value=provider_payload())
    def test_analyze_idempotency_key_reuses_session(self, gateway):
        first = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
            HTTP_IDEMPOTENCY_KEY="capture-request-001",
        )
        second = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
            HTTP_IDEMPOTENCY_KEY="capture-request-001",
        )

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_201_CREATED)
        self.assertEqual(first.data["data"]["id"], second.data["data"]["id"])
        self.assertEqual(MealAnalysisSession.objects.filter(user=self.user).count(), 1)
        gateway.assert_called_once()

    @patch("ai_meals.gateway.AIMealGateway.analyze", return_value=provider_payload())
    def test_expired_analysis_cannot_be_confirmed(self, gateway):
        analyze = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
        )
        analysis_id = analyze.data["data"]["id"]
        MealAnalysisSession.objects.filter(id=analysis_id).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )

        detail = self.client.get(f"/api/nutrition/ai-meals/{analysis_id}/")
        self.assertEqual(detail.status_code, status.HTTP_200_OK)
        self.assertEqual(
            detail.data["data"]["status"],
            MealAnalysisSession.STATUS_EXPIRED,
        )
        confirmation = self.client.patch(
            f"/api/nutrition/ai-meals/{analysis_id}/confirmation/",
            {
                "selected_dish_label": "Expired bowl",
                "meal_type": "lunch",
                "components": [
                    {
                        "food_item_id": self.rice.id,
                        "confirmed_grams": 100,
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(confirmation.status_code, status.HTTP_409_CONFLICT)

    @patch("ai_meals.gateway.AIMealGateway.analyze")
    def test_mapping_never_exposes_another_users_food(self, gateway):
        private_food = create_food_item(
            name="Private family recipe",
            calories_100g=100,
            created_by=self.other_user,
        )
        AIIngredientMapping.objects.create(
            provider_id="private-recipe",
            provider_label="Private family recipe",
            food_item=private_food,
        )
        payload = provider_payload()
        payload["suggested_ingredients"] = [
            {
                "ingredient_id": "private-recipe",
                "name": "Private family recipe",
                "confidence": 0.9,
                "default_percentage": 1,
            }
        ]
        gateway.return_value = payload

        response = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        component = response.data["data"]["components"][0]
        self.assertIsNone(component["mapped_food_item"])

    def test_invalid_image_is_rejected_before_provider_call(self):
        response = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {
                "image": SimpleUploadedFile(
                    "fake.jpg",
                    b"not-an-image",
                    content_type="image/jpeg",
                )
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(MealAnalysisSession.objects.count(), 0)

    @patch(
        "ai_meals.gateway.AIMealGateway.analyze",
        side_effect=AIServiceError("offline", code="analysis_unavailable"),
    )
    def test_provider_failure_is_persisted_and_reported_as_retryable(self, gateway):
        response = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        session = MealAnalysisSession.objects.get(id=response.data["analysis_id"])
        self.assertEqual(session.status, MealAnalysisSession.STATUS_FAILED)
        self.assertEqual(session.failure_code, "analysis_unavailable")

    @patch(
        "ai_meals.services.MealAnalysisService._persist_provider_result",
        side_effect=RuntimeError("database rejected provider text"),
    )
    @patch("ai_meals.gateway.AIMealGateway.analyze", return_value=provider_payload())
    def test_persistence_failure_does_not_leave_analyzing_session(
        self,
        gateway,
        persist_result,
    ):
        response = self.client.post(
            "/api/nutrition/ai-meals/analyze/",
            {"image": valid_png()},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(response.data["code"], "analysis_persistence_failure")
        session = MealAnalysisSession.objects.get(id=response.data["analysis_id"])
        self.assertEqual(session.status, MealAnalysisSession.STATUS_FAILED)
        self.assertEqual(session.failure_code, "analysis_persistence_failure")
