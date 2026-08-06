from __future__ import annotations

from datetime import date, timedelta

from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.medication_serializers import (
    MedicationHistoryQuerySerializer,
    DoseSkippedActionSerializer,
    DoseSnoozeActionSerializer,
    DoseTakenActionSerializer,
    MedicationPlanWriteSerializer,
    PrnDoseActionSerializer,
    serialize_adherence,
    serialize_dose_log,
    serialize_medication,
)
from core.models import ConditionMedication, ConditionMedicationLog
from core.services.medication_adherence_service import MedicationAdherenceService
from core.services.medication_dose_workflow_service import MedicationDoseWorkflowService
from core.services.medication.dose_materialization_service import DoseMaterializationService
from core.services.medication_plan_service import MedicationPlanService
from core.services.medication_read_service import MedicationReadService


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

    def _dose_action_payload(self, log: ConditionMedicationLog) -> dict:
        dose_payload = serialize_dose_log(log)
        target_date = log.scheduled_date or timezone.localdate()
        summary = MedicationAdherenceService.counts_for_day(
            user=self.request.user,
            target_date=target_date,
        )
        next_due = MedicationAdherenceService.next_due(user=self.request.user)
        return {
            **dose_payload,
            "dose_log": dose_payload,
            "day_summary": summary,
            "next_dose": serialize_dose_log(next_due) if next_due else None,
        }

    def _today_read_model(self, *, target_date=None) -> dict:
        target_date = target_date or timezone.localdate()
        logs = list(MedicationReadService.get_today_dose_logs(user=self.request.user, target_date=target_date))
        doses = [serialize_dose_log(log) for log in logs]
        completed = {
            ConditionMedicationLog.STATUS_TAKEN,
            ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
            ConditionMedicationLog.STATUS_TAKEN_LATE,
            ConditionMedicationLog.STATUS_MISSED,
            ConditionMedicationLog.STATUS_SKIPPED,
        }
        return {
            "server_now": timezone.now().isoformat(),
            "timezone": self._primary_medication_timezone(),
            "selected_date": target_date.isoformat(),
            "summary": MedicationAdherenceService.counts_for_day(
                user=self.request.user,
                target_date=target_date,
            ),
            "doses": doses,
            "grouped": {
                "upcoming": [
                    item
                    for item in doses
                    if item.get("raw_status") not in completed
                ],
                "completed": [
                    item
                    for item in doses
                    if item.get("raw_status") in completed
                ],
            },
        }

    def _primary_medication_timezone(self) -> str:
        medication = (
            MedicationReadService.get_medication_plans(user=self.request.user)
            .filter(timezone__isnull=False)
            .exclude(timezone="")
            .first()
        )
        return medication.timezone if medication else "UTC"

    def list(self, request):
        return Response([serialize_medication(item) for item in self._queryset().filter(is_active=True)])

    def retrieve(self, request, pk=None):
        return Response(serialize_medication(self._get_medication(pk)))

    def create(self, request):
        serializer = MedicationPlanWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        medication = MedicationPlanService.create_medication_plan(
            user=request.user,
            payload=dict(serializer.validated_data),
        )
        today_preview = MedicationReadService.get_today_preview_for_medication(
            medication=medication,
        )
        medication_payload = serialize_medication(medication)
        return Response(
            {
                "medication": medication_payload,
                "schedules": medication_payload["schedules"],
                "today_doses_preview": [serialize_dose_log(log) for log in today_preview],
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
        return Response(
            {
                "medication": serialize_medication(medication),
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
            }
        )

    @action(detail=False, methods=["get"])
    def today(self, request):
        selected_date = request.query_params.get("date")
        target_date = None
        if selected_date:
            try:
                target_date = date.fromisoformat(selected_date)
            except ValueError:
                return Response({"date": "Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)
        return Response(self._today_read_model(target_date=target_date))

    @action(detail=False, methods=["post"])
    def materialize(self, request):
        result = DoseMaterializationService.materialize_user(user=request.user)
        return Response(result)

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
        return Response(self._dose_action_payload(log))

    @action(detail=False, methods=["post"], url_path=r"doses/(?P<log_id>[^/.]+)/missed")
    def dose_missed(self, request, log_id=None):
        log = MedicationDoseWorkflowService.mark_missed(user=request.user, log_id=log_id)
        return Response(self._dose_action_payload(log))

    @action(detail=False, methods=["post"], url_path=r"doses/(?P<log_id>[^/.]+)/skipped")
    def dose_skipped(self, request, log_id=None):
        serializer = DoseSkippedActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = MedicationDoseWorkflowService.mark_skipped(
            user=request.user,
            log_id=log_id,
            reason=serializer.validated_data.get("reason", ""),
        )
        return Response(self._dose_action_payload(log))

    @action(detail=False, methods=["post"], url_path=r"doses/(?P<log_id>[^/.]+)/snooze")
    def dose_snooze(self, request, log_id=None):
        serializer = DoseSnoozeActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = MedicationDoseWorkflowService.snooze(
            user=request.user,
            log_id=log_id,
            snoozed_until=serializer.validated_data["snoozed_until"],
        )
        return Response(self._dose_action_payload(log))

    @action(detail=True, methods=["post"], url_path="prn-dose")
    def prn_dose(self, request, pk=None):
        serializer = PrnDoseActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = MedicationDoseWorkflowService.log_prn_taken(
            user=request.user,
            medication_id=pk,
            taken_at=serializer.validated_data.get("taken_at"),
            dose_taken_amount=serializer.validated_data.get("dose_taken_amount"),
            notes=serializer.validated_data.get("notes", ""),
        )
        return Response(self._dose_action_payload(log), status=status.HTTP_201_CREATED)

    @action(detail=False, methods=["get"])
    def history(self, request):
        serializer = MedicationHistoryQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        page = serializer.validated_data["page"]
        page_size = serializer.validated_data["page_size"]
        filter_status = serializer.validated_data["status"]
        status_map = {
            "taken": [
                ConditionMedicationLog.STATUS_TAKEN,
                ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
                ConditionMedicationLog.STATUS_TAKEN_LATE,
            ],
            "missed": [ConditionMedicationLog.STATUS_MISSED],
            "skipped": [ConditionMedicationLog.STATUS_SKIPPED],
            "snoozed": [ConditionMedicationLog.STATUS_SNOOZED],
            "pending": [ConditionMedicationLog.STATUS_PENDING],
            "overdue": [ConditionMedicationLog.STATUS_OVERDUE],
        }
        queryset = (
            ConditionMedicationLog.objects.filter(medication__user=request.user)
            .select_related("medication", "medication__user_condition", "medication__user_condition__condition_type")
            .order_by("-scheduled_date", "-scheduled_for", "-id")
        )
        if filter_status != "all":
            queryset = queryset.filter(status__in=status_map[filter_status])
        total = queryset.count()
        start = (page - 1) * page_size
        logs = list(queryset[start : start + page_size])
        groups: list[dict] = []
        groups_by_date: dict[str, dict] = {}
        for log in logs:
            key = log.scheduled_date.isoformat()
            group = groups_by_date.get(key)
            if group is None:
                group = {"date": key, "items": []}
                groups_by_date[key] = group
                groups.append(group)
            group["items"].append(serialize_dose_log(log))
        return Response(
            {
                "server_now": timezone.now().isoformat(),
                "page": page,
                "page_size": page_size,
                "total": total,
                "has_next": start + page_size < total,
                "status": filter_status,
                "groups": groups,
            }
        )

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
