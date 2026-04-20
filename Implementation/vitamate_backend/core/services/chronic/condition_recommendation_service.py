from __future__ import annotations


class ConditionRecommendationService:
    @staticmethod
    def normalize(recommendations: list[dict] | None) -> list[dict]:
        normalized = []
        seen = set()
        for item in recommendations or []:
            code = str(item.get("code") or "").strip()
            message = str(item.get("message") or "").strip()
            if not code or not message:
                continue
            key = (code, message)
            if key in seen:
                continue
            seen.add(key)
            normalized.append({"code": code, "message": message})
        return normalized
