from __future__ import annotations

from datetime import timedelta

from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.medication_serializers import (
    DoseSkippedActionSerializer,
    DoseSnoozeActionSerializer,
    DoseTakenActionSerializer,
    MedicationPlanWriteSerializer,
    serialize_adherence,
    serialize_dose_log,
    serialize_medication,
)
from core.models import ConditionMedication, ConditionMedicationLog
from core.services.medication_adherence_service import MedicationAdherenceService
from core.services.medication_dose_workflow_service import MedicationDoseWorkflowService
from core.services.medication_plan_service import MedicationPlanService
from core.services.medication_read_service import MedicationReadService
from core.services.medication_schedule_service import MedicationScheduleService
from core.services.orchestration.notification_dispatcher import NotificationDispatcher


class MedicationViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def _queryset(self):
        return MedicationReadService.get_medication_plans(user=self.request.user)

    def _get_medication(self, pk) -> ConditionMedication:
        medication = self._queryset().filter(pk=pk).first()
        if medication is None:
            from rest_framework.exceptions import NotFound

            raise NotFound("Medication not found.")
        return medication

    def _ensure_generated_doses(self) -> None:
        # TODO: move dose generation/overdue marking fully out of read endpoints.
        now = timezone.now()
        MedicationDoseWorkflowService.mark_overdue_pending_doses(now=now)
        for medication in MedicationReadService.get_active_medication_plans(user=self.request.user):
            MedicationScheduleService.generate_pending_doses(
                medication=medication,
                from_dt=now - timedelta(hours=1),
                to_dt=now + timedelta(hours=48),
            )

    def list(self, request):
        self._ensure_generated_doses()
        return Response([serialize_medication(item) for item in self._queryset().filter(is_active=True)])

    def retrieve(self, request, pk=None):
        self._ensure_generated_doses()
        return Response(serialize_medication(self._get_medication(pk)))

    def create(self, request):
        serializer = MedicationPlanWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        medication = MedicationPlanService.create_medication_plan(
            user=request.user,
            payload=dict(serializer.validated_data),
        )
        self._ensure_generated_doses()
        today_preview = MedicationReadService.get_today_preview_for_medication(
            medication=medication,
        )
        medication_payload = serialize_medication(medication)
        return Response(
            {
                "medication": medication_payload,
                "schedules": medication_payload["schedules"],
                "today_doses_preview": [serialize_dose_log(log) for log in today_preview],
                "reminder_sync": NotificationDispatcher.build_reminder_sync_payload(user=request.user),
            },
            status=status.HTTP_201_CREATED,
        )

    def partial_update(self, request, pk=None):
        medication = self._get_medication(pk)
        serializer = MedicationPlanWriteSerializer(data=request.data, partial=True)
        serializer.instance = medication
        serializer.is_valid(raise_exception=True)
        medication = MedicationPlanService.update_medication_plan(
            user=request.user,
            medication_id=medication.id,
            payload=dict(serializer.validated_data),
        )
        self._ensure_generated_doses()
        return Response(
            {
                "medication": serialize_medication(medication),
                "reminder_sync": NotificationDispatcher.build_reminder_sync_payload(user=request.user),
            }
        )

    def update(self, request, pk=None):
        return self.partial_update(request, pk=pk)

    @action(detail=True, methods=["post"])
    def deactivate(self, request, pk=None):
        medication = MedicationPlanService.deactivate_medication_plan(
            user=request.user,
            medication_id=pk,
        )
        return Response(
            {
                "medication": serialize_medication(medication),
                "reminder_sync": NotificationDispatcher.build_reminder_sync_payload(user=request.user),
            }
        )

    @action(detail=False, methods=["get"])
    def today(self, request):
        self._ensure_generated_doses()
        logs = MedicationReadService.get_today_dose_logs(user=request.user)
        return Response([serialize_dose_log(log) for log in logs])

    @action(detail=False, methods=["post"], url_path=r"doses/(?P<log_id>[^/.]+)/taken")
    def dose_taken(self, request, log_id=None):
        serializer = DoseTakenActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = MedicationDoseWorkflowService.mark_taken(
            user=request.user,
            log_id=log_id,
            taken_at=serializer.validated_data.get("taken_at"),
            dose_taken_amount=serializer.validated_data.get("dose_taken_amount"),
        )
        return Response(serialize_dose_log(log))

    @action(detail=False, methods=["post"], url_path=r"doses/(?P<log_id>[^/.]+)/missed")
    def dose_missed(self, request, log_id=None):
        log = MedicationDoseWorkflowService.mark_missed(user=request.user, log_id=log_id)
        return Response(serialize_dose_log(log))

    @action(detail=False, methods=["post"], url_path=r"doses/(?P<log_id>[^/.]+)/skipped")
    def dose_skipped(self, request, log_id=None):
        serializer = DoseSkippedActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = MedicationDoseWorkflowService.mark_skipped(
            user=request.user,
            log_id=log_id,
            reason=serializer.validated_data.get("reason", ""),
        )
        return Response(serialize_dose_log(log))

    @action(detail=False, methods=["post"], url_path=r"doses/(?P<log_id>[^/.]+)/snooze")
    def dose_snooze(self, request, log_id=None):
        serializer = DoseSnoozeActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = MedicationDoseWorkflowService.snooze(
            user=request.user,
            log_id=log_id,
            snoozed_until=serializer.validated_data["snoozed_until"],
        )
        return Response(serialize_dose_log(log))

    @action(detail=True, methods=["get"])
    def adherence(self, request, pk=None):
        medication = self._get_medication(pk)
        end_date = timezone.localdate()
        start_date = end_date - timedelta(days=29)
        summary = MedicationAdherenceService.get_medication_adherence(
            medication=medication,
            start_date=start_date,
            end_date=end_date,
        )
        return Response(serialize_adherence(summary))

    @action(detail=False, methods=["get"], url_path="adherence-summary")
    def adherence_summary(self, request):
        end_date = timezone.localdate()
        start_date = end_date - timedelta(days=29)
        summary = MedicationAdherenceService.get_user_adherence(
            user=request.user,
            start_date=start_date,
            end_date=end_date,
        )
        return Response(serialize_adherence(summary))

    @action(detail=False, methods=["get"], url_path="reminder-sync")
    def reminder_sync(self, request):
        return Response(NotificationDispatcher.build_reminder_sync_payload(user=request.user))
