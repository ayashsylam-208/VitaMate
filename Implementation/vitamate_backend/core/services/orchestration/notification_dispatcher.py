from __future__ import annotations

from django.utils import timezone

from core.models import NotificationDispatchRecord
from core.repositories.health_state_repository import NotificationDispatchRepository
from core.services.medication_reminder_sync_service import MedicationReminderSyncService


class NotificationDispatcher:
    def dispatch_candidates(self, *, user, candidates: list[dict]) -> list[dict]:
        now = timezone.now()
        persisted: list[dict] = []
        for candidate in candidates:
            dedupe_key = str(candidate.get("dedupe_key") or "").strip()
            if not dedupe_key:
                continue
            latest = NotificationDispatchRepository.latest_by_dedupe_key(
                user=user,
                dedupe_key=dedupe_key,
            )
            cooldown_until = candidate.get("cooldown_until")
            status = NotificationDispatchRecord.STATUS_DISPATCHED
            if latest is not None and latest.cooldown_until and latest.cooldown_until > now:
                status = NotificationDispatchRecord.STATUS_SUPPRESSED
                cooldown_until = latest.cooldown_until
            NotificationDispatchRepository.create_record(
                user=user,
                notification_type=str(candidate.get("type") or "generic"),
                channel=str(candidate.get("channel") or ""),
                priority=int(candidate.get("priority") or 50),
                dedupe_key=dedupe_key,
                payload=candidate.get("payload") or {},
                status=status,
                cooldown_until=cooldown_until,
                last_dispatched_at=now if status == NotificationDispatchRecord.STATUS_DISPATCHED else None,
            )
            persisted.append(
                {
                    "type": str(candidate.get("type") or "generic"),
                    "channel": str(candidate.get("channel") or ""),
                    "priority": int(candidate.get("priority") or 50),
                    "dedupe_key": dedupe_key,
                    "status": status,
                }
            )
        return persisted

    @staticmethod
    def build_reminder_sync_payload(*, user) -> dict:
        return MedicationReminderSyncService.build_reminder_sync_payload(user=user)

    @staticmethod
    def build_sync_payload(*, user) -> dict:
        records = NotificationDispatchRecord.objects.filter(user=user).order_by("-updated_at", "-id")[:20]
        return {
            "reminder_sync": MedicationReminderSyncService.build_reminder_sync_payload(user=user),
            "intents": [
                {
                    "type": record.notification_type,
                    "channel": record.channel,
                    "priority": record.priority,
                    "dedupe_key": record.dedupe_key,
                    "status": record.status,
                    "payload": record.payload,
                    "cooldown_until": record.cooldown_until.isoformat() if record.cooldown_until else None,
                    "last_dispatched_at": (
                        record.last_dispatched_at.isoformat()
                        if record.last_dispatched_at
                        else None
                    ),
                }
                for record in records
            ],
        }
