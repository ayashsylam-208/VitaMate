from __future__ import annotations

from datetime import timedelta

from django.utils import timezone

from manager.models import AccountDeletionRequest, PrivacyExportRequest
from manager.services.read_model_service import ManagerReadModelService


class PrivacyService:
    EXPORT_EXPIRY_DAYS = 7
    DELETION_GRACE_DAYS = 14

    @classmethod
    def request_export(cls, *, user) -> dict:
        now = timezone.now()
        row = PrivacyExportRequest.objects.create(
            user=user,
            status=PrivacyExportRequest.STATUS_READY,
            completed_at=now,
            expires_at=now + timedelta(days=cls.EXPORT_EXPIRY_DAYS),
            payload={
                "overview": ManagerReadModelService.overview(
                    user=user,
                    request_id=f"privacy-export-{user.id}-{int(now.timestamp())}",
                ).get("data"),
            },
        )
        return {"data": ManagerReadModelService._export_payload(row)}

    @classmethod
    def request_account_deletion(cls, *, user, reason: str = "") -> dict:
        now = timezone.now()
        row, _ = AccountDeletionRequest.objects.update_or_create(
            user=user,
            status=AccountDeletionRequest.STATUS_REQUESTED,
            defaults={
                "reason": reason[:240],
                "requested_at": now,
                "grace_period_ends_at": now + timedelta(days=cls.DELETION_GRACE_DAYS),
                "resolved_at": None,
            },
        )
        return {"data": ManagerReadModelService._deletion_payload(row)}

    @classmethod
    def cancel_account_deletion(cls, *, user) -> dict:
        now = timezone.now()
        updated = AccountDeletionRequest.objects.filter(
            user=user,
            status=AccountDeletionRequest.STATUS_REQUESTED,
        ).update(
            status=AccountDeletionRequest.STATUS_CANCELLED,
            resolved_at=now,
        )
        return {"data": {"cancelled": bool(updated), "resolved_at": now.isoformat()}}
