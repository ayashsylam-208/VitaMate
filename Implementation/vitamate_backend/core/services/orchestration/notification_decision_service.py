from __future__ import annotations

from datetime import timedelta

from django.utils import timezone


class NotificationDecisionService:
    WARNING_PRIORITY = {
        "critical": 95,
        "high": 85,
        "warning": 75,
        "moderate": 70,
        "info": 40,
    }

    @classmethod
    def decide(
        cls,
        *,
        delta_payload: dict,
    ) -> list[dict]:
        now = timezone.now()
        metrics_before = dict(delta_payload.get("metrics_before") or {})
        metrics_after = dict(delta_payload.get("metrics_after") or {})
        state_date = str(delta_payload.get("state_date") or "")
        candidates: list[dict] = []

        for warning in delta_payload.get("warnings_added") or []:
            code = str(warning.get("code") or "warning")
            level = str(warning.get("level") or "warning").lower()
            candidates.append(
                {
                    "type": "warning_triggered",
                    "channel": "health_alert",
                    "priority": cls.WARNING_PRIORITY.get(level, 70),
                    "dedupe_key": f"warning:{code}:{state_date}",
                    "cooldown_until": now + timedelta(hours=6),
                    "payload": {
                        "warning": warning,
                        "state_date": state_date,
                    },
                }
            )

        for warning in delta_payload.get("warnings_resolved") or []:
            code = str(warning.get("code") or "warning")
            candidates.append(
                {
                    "type": "warning_resolved",
                    "channel": "health_alert",
                    "priority": 35,
                    "dedupe_key": f"warning_resolved:{code}:{state_date}",
                    "cooldown_until": now + timedelta(hours=2),
                    "payload": {
                        "warning": warning,
                        "state_date": state_date,
                    },
                }
            )

        before_adherence = float(metrics_before.get("medication_adherence_percent") or 0)
        after_adherence = float(metrics_after.get("medication_adherence_percent") or 0)
        if before_adherence - after_adherence >= 10:
            candidates.append(
                {
                    "type": "medication_adherence_drop",
                    "channel": "medication",
                    "priority": 80,
                    "dedupe_key": f"med_adherence_drop:{state_date}",
                    "cooldown_until": now + timedelta(hours=8),
                    "payload": {
                        "before": before_adherence,
                        "after": after_adherence,
                        "state_date": state_date,
                    },
                }
            )

        before_overdue = int(metrics_before.get("medication_overdue_today") or 0)
        after_overdue = int(metrics_after.get("medication_overdue_today") or 0)
        if after_overdue > before_overdue and after_overdue > 0:
            candidates.append(
                {
                    "type": "medication_overdue",
                    "channel": "medication",
                    "priority": 90,
                    "dedupe_key": f"medication_overdue:{state_date}",
                    "cooldown_until": now + timedelta(hours=4),
                    "payload": {
                        "overdue_today": after_overdue,
                        "state_date": state_date,
                    },
                }
            )

        for achievement in delta_payload.get("achievements_added") or []:
            code = str(achievement.get("code") or "achievement")
            candidates.append(
                {
                    "type": "achievement",
                    "channel": "achievement",
                    "priority": 45,
                    "dedupe_key": f"achievement:{code}:{state_date}",
                    "cooldown_until": now + timedelta(hours=12),
                    "payload": {
                        "achievement": achievement,
                        "state_date": state_date,
                    },
                }
            )

        return candidates
