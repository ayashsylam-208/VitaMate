from __future__ import annotations

import requests
from django.conf import settings


class AIServiceError(RuntimeError):
    def __init__(self, message, *, code="ai_service_error", retryable=True):
        super().__init__(message)
        self.code = code
        self.retryable = retryable


class AIMealGateway:
    def analyze(
        self,
        *,
        image_file,
        filename,
        content_type,
        auto_weight_mode="try",
        dishware_profile_id=None,
        plate_diameter_cm=None,
    ):
        data = {"auto_weight_mode": auto_weight_mode}
        if dishware_profile_id:
            data["dishware_profile_id"] = dishware_profile_id
        if plate_diameter_cm is not None:
            data["plate_diameter_cm"] = str(plate_diameter_cm)
        headers = {}
        if settings.AI_MEALS_SERVICE_TOKEN:
            headers["X-VitaMate-Service-Token"] = settings.AI_MEALS_SERVICE_TOKEN

        try:
            response = requests.post(
                f"{settings.AI_MEALS_BASE_URL}/analyze",
                files={"image": (filename, image_file, content_type)},
                data=data,
                headers=headers,
                timeout=settings.AI_MEALS_TIMEOUT_SECONDS,
            )
        except requests.Timeout as exc:
            raise AIServiceError(
                "The meal analysis service timed out.",
                code="analysis_timeout",
            ) from exc
        except requests.RequestException as exc:
            raise AIServiceError(
                "The meal analysis service is unavailable.",
                code="analysis_unavailable",
            ) from exc

        if response.status_code >= 500:
            raise AIServiceError(
                "The meal analysis service failed.",
                code="analysis_provider_failure",
            )
        if response.status_code >= 400:
            detail = self._detail(response)
            raise AIServiceError(
                detail or "The image was rejected by the analysis service.",
                code="analysis_rejected",
                retryable=False,
            )
        try:
            payload = response.json()
        except ValueError as exc:
            raise AIServiceError(
                "The meal analysis service returned invalid JSON.",
                code="analysis_invalid_response",
            ) from exc
        if not isinstance(payload, dict):
            raise AIServiceError(
                "The meal analysis response has an invalid shape.",
                code="analysis_invalid_response",
            )
        return payload

    @staticmethod
    def _detail(response):
        try:
            payload = response.json()
        except ValueError:
            return ""
        if isinstance(payload, dict):
            return str(payload.get("detail") or payload.get("message") or "")
        return ""
