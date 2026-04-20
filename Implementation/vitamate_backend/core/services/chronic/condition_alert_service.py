from __future__ import annotations

from django.utils import timezone

from core.models import ConditionAlert


class ConditionAlertService:
    @staticmethod
    def sync_alerts(*, user_condition, alerts: list[dict], on_date=None) -> list[ConditionAlert]:
        on_date = on_date or timezone.localdate()
        persisted = []
        for item in alerts:
            code = str(item.get("code") or "").strip()
            if not code:
                continue
            defaults = {
                "level": str(item.get("level") or item.get("severity") or "").strip(),
                "message": str(item.get("message") or item.get("title") or code.replace("_", " ").title()).strip(),
                "alert_type": item.get("alert_type") or ConditionAlert.TYPE_MONITORING,
                "status": ConditionAlert.STATUS_OPEN,
                "metadata": dict(item.get("metadata") or {}),
            }
            alert, _ = ConditionAlert.objects.update_or_create(
                user_condition=user_condition,
                code=code,
                created_at__date=on_date,
                defaults=defaults,
            )
            persisted.append(alert)
        return persisted
