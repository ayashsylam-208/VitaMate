from io import BytesIO
from unittest.mock import Mock, patch

import requests
from django.test import SimpleTestCase, override_settings

from ai_meals.gateway import AIMealGateway, AIServiceError


@override_settings(
    AI_MEALS_BASE_URL="http://127.0.0.1:8010",
    AI_MEALS_TIMEOUT_SECONDS=42,
    AI_MEALS_SERVICE_TOKEN="service-token-with-at-least-32-characters",
)
class AIMealGatewayContractTests(SimpleTestCase):
    @patch("ai_meals.gateway.requests.post")
    def test_analyze_sends_service_token_and_auto_weight_mode(self, post):
        response = Mock(status_code=200)
        response.json.return_value = {"status": "ok", "suggested_ingredients": []}
        post.return_value = response

        result = AIMealGateway().analyze(
            image_file=BytesIO(b"normalized-image"),
            filename="meal-analysis.jpg",
            content_type="image/jpeg",
        )

        self.assertEqual(result["status"], "ok")
        _, kwargs = post.call_args
        self.assertEqual(kwargs["data"]["auto_weight_mode"], "try")
        self.assertEqual(
            kwargs["headers"]["X-VitaMate-Service-Token"],
            "service-token-with-at-least-32-characters",
        )
        self.assertEqual(kwargs["timeout"], 42)
        self.assertEqual(kwargs["files"]["image"][0], "meal-analysis.jpg")

    @patch("ai_meals.gateway.requests.post", side_effect=requests.Timeout)
    def test_timeout_is_exposed_as_retryable_domain_error(self, post):
        with self.assertRaises(AIServiceError) as raised:
            AIMealGateway().analyze(
                image_file=BytesIO(b"image"),
                filename="meal.jpg",
                content_type="image/jpeg",
            )

        self.assertEqual(raised.exception.code, "analysis_timeout")
        self.assertTrue(raised.exception.retryable)

    @patch("ai_meals.gateway.requests.post")
    def test_provider_validation_error_is_not_retryable(self, post):
        response = Mock(status_code=422)
        response.json.return_value = {"detail": "Unsupported image."}
        post.return_value = response

        with self.assertRaises(AIServiceError) as raised:
            AIMealGateway().analyze(
                image_file=BytesIO(b"image"),
                filename="meal.jpg",
                content_type="image/jpeg",
            )

        self.assertEqual(raised.exception.code, "analysis_rejected")
        self.assertFalse(raised.exception.retryable)
        self.assertEqual(str(raised.exception), "Unsupported image.")

    @patch("ai_meals.gateway.requests.post")
    def test_invalid_json_is_rejected(self, post):
        response = Mock(status_code=200)
        response.json.side_effect = ValueError("invalid")
        post.return_value = response

        with self.assertRaises(AIServiceError) as raised:
            AIMealGateway().analyze(
                image_file=BytesIO(b"image"),
                filename="meal.jpg",
                content_type="image/jpeg",
            )

        self.assertEqual(raised.exception.code, "analysis_invalid_response")
