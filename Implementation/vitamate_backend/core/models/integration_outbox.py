from django.conf import settings
from django.db import models
from django.utils import timezone


class IntegrationOutboxEvent(models.Model):
    STATUS_PENDING = "pending"
    STATUS_PROCESSING = "processing"
    STATUS_PROCESSED = "processed"
    STATUS_FAILED = "failed"
    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_PROCESSING, "Processing"),
        (STATUS_PROCESSED, "Processed"),
        (STATUS_FAILED, "Failed"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="integration_outbox_events",
    )
    event_type = models.CharField(max_length=64, db_index=True)
    dedupe_key = models.CharField(max_length=160, unique=True)
    payload = models.JSONField(default=dict, blank=True)
    status = models.CharField(
        max_length=16,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
        db_index=True,
    )
    attempts = models.PositiveSmallIntegerField(default=0)
    last_error = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(default=timezone.now, db_index=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("created_at", "id")
        indexes = [
            models.Index(
                fields=("status", "created_at"),
                name="integration_outbox_pending_idx",
            )
        ]

