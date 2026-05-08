from __future__ import annotations

from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.chronic_serializers import (
    ConditionDoseActionSerializer,
    ConditionMedicationSerializer,
    ConditionMedicationScheduleSerializer,
    ConditionMedicationWriteSerializer,
    ConditionReadingSerializer,
    ConditionSummarySerializer,
    ConditionTypeSerializer,
    CreateUserConditionSerializer,
    HealthIndicatorRecordSerializer,
    SupportedConditionTypeSerializer,
    UpdateUserConditionSerializer,
    UserConditionWriteSerializer,
)
from core.models import (
    ConditionMedication,
    ConditionMedicationSchedule,
    ConditionType,
    HealthIndicatorRecord,
    UserCondition,
)
from core.services.chronic_condition_service import ChronicConditionService
from core.services.condition_catalog_service import ConditionCatalogService
from core.services.condition_measurement_workflow_service import ConditionMeasurementWorkflowService
from core.services.condition_medication_service import ConditionMedicationService
from core.services.condition_read_service import ConditionReadService
from core.services.condition_setup_service import ConditionSetupService
from core.services.medication_plan_service import MedicationPlanService


measurement_workflow_service = ConditionMeasurementWorkflowService()


class ConditionTypeViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ConditionTypeSerializer

    def get_queryset(self):
        return ConditionReadService.get_condition_types()

    @action(detail=False, methods=["get"], url_path="supported")
    def supported(self, request):
        payload = ConditionCatalogService.supported_condition_payloads(user=request.user)
        serializer = SupportedConditionTypeSerializer(payload, many=True)
        return Response(serializer.data)


class UserConditionViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = UserConditionWriteSerializer

    def _compact_view_requested(self) -> bool:
        return self.request.query_params.get("view") == "compact"

    def get_queryset(self):
        compact = self.action == "list" and self._compact_view_requested()
        return ConditionReadService.get_user_conditions(user=self.request.user, compact=compact)

    def get_serializer_class(self):
        if self.action == "create":
            return CreateUserConditionSerializer
        if self.action in {"update", "partial_update"}:
            return UpdateUserConditionSerializer
        return UserConditionWriteSerializer

    @staticmethod
    def _condition_service_payload(validated_data: dict) -> tuple[int | None, dict]:
        data = dict(validated_data)
        condition_type_id = data.pop("condition_type", None)
        target_overrides = data.pop("target_overrides", None)
        medications_data = data.pop("medications", None)
        condition_status = data.pop("condition_status", None)
        severity = data.pop("severity", None)
        severity_code = data.pop("severity_code", None)
        payload = {
            **data,
            "target_overrides": target_overrides,
            "medications_data": medications_data,
            "condition_status": condition_status,
            "severity": severity,
            "severity_code": severity_code,
        }
        return condition_type_id, payload

    @staticmethod
    def _condition_error_response(exc: ValueError) -> Response:
        message = str(exc)
        field_errors = {
            "This condition is already active for the current user.": {"condition_type": [message]},
            "This chronic condition is not supported in v1.": {"condition_type": [message]},
            "severity is required.": {"severity": [message]},
            "severity must match one of the supported severity options.": {"severity": [message]},
            "condition_status must be a supported status value.": {"condition_status": [message]},
        }
        payload = field_errors.get(message, {"detail": message})
        return Response(payload, status=status.HTTP_400_BAD_REQUEST)

    def list(self, request, *args, **kwargs):
        if self._compact_view_requested():
            data = [
                ChronicConditionService.condition_compact_overview(user_condition=condition)
                for condition in self.get_queryset()
            ]
            return Response(data)
        data = [
            ChronicConditionService.condition_overview(user_condition=condition)
            for condition in self.get_queryset()
        ]
        return Response(data)

    def retrieve(self, request, *args, **kwargs):
        condition = self.get_object()
        return Response(ChronicConditionService.condition_overview(user_condition=condition))

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        condition_type_id, payload = self._condition_service_payload(serializer.validated_data)
        try:
            condition = ConditionSetupService().create_condition(
                user=request.user,
                condition_type_id=condition_type_id,
                **payload,
            )
        except ValueError as exc:
            return self._condition_error_response(exc)
        payload = (
            ChronicConditionService.condition_compact_overview(user_condition=condition)
            if self._compact_view_requested()
            else ChronicConditionService.condition_overview(user_condition=condition)
        )
        return Response(payload, status=status.HTTP_201_CREATED)

    def partial_update(self, request, *args, **kwargs):
        condition = self.get_object()
        serializer = self.get_serializer(condition, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        _, payload = self._condition_service_payload(serializer.validated_data)
        try:
            condition = ConditionSetupService().update_condition(
                user_condition=condition,
                **payload,
            )
        except ValueError as exc:
            return self._condition_error_response(exc)
        payload = (
            ChronicConditionService.condition_compact_overview(user_condition=condition)
            if self._compact_view_requested()
            else ChronicConditionService.condition_overview(user_condition=condition)
        )
        return Response(payload)

    def update(self, request, *args, **kwargs):
        condition = self.get_object()
        serializer = self.get_serializer(condition, data=request.data)
        serializer.is_valid(raise_exception=True)
        _, payload = self._condition_service_payload(serializer.validated_data)
        try:
            condition = ConditionSetupService().update_condition(
                user_condition=condition,
                **payload,
            )
        except ValueError as exc:
            return self._condition_error_response(exc)
        payload = (
            ChronicConditionService.condition_compact_overview(user_condition=condition)
            if self._compact_view_requested()
            else ChronicConditionService.condition_overview(user_condition=condition)
        )
        return Response(payload)

    @action(detail=True, methods=["post"])
    def deactivate(self, request, pk=None):
        condition = self.get_object()
        condition = ConditionSetupService().update_condition(
            user_condition=condition,
            is_active=False,
            condition_status=UserCondition.STATUS_INACTIVE,
        )
        return Response(
            {
                "id": condition.id,
                "status": condition.status,
                "is_active": condition.is_active,
            }
        )

    @action(detail=True, methods=["post"])
    def evaluate(self, request, pk=None):
        condition = self.get_object()
        payload = ChronicConditionService.condition_overview(user_condition=condition)
        return Response(payload)

    @action(detail=True, methods=["get", "post"])
    def readings(self, request, pk=None):
        condition = self.get_object()
        if request.method.lower() == "get":
            return Response(ChronicConditionService.readings_timeline(user_condition=condition))

        serializer = ConditionReadingSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            payload = measurement_workflow_service.log_reading(
                user=request.user,
                user_condition=condition,
                payload=serializer.validated_data,
            )
        except (PermissionError, ValueError) as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(payload, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=["get"])
    def summary(self, request, pk=None):
        condition = self.get_object()
        payload = ChronicConditionService.condition_summary(user_condition=condition)
        serializer = ConditionSummarySerializer(payload)
        return Response(serializer.data)


class ConditionMedicationViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = ConditionReadService.get_condition_medications(
            user=self.request.user,
            user_condition_id=self.request.query_params.get("user_condition"),
        )
        return queryset

    def get_serializer_class(self):
        if self.action in {"create", "update", "partial_update"}:
            return ConditionMedicationWriteSerializer
        return ConditionMedicationSerializer

    @staticmethod
    def _medication_payload(validated_data: dict, *, existing=None) -> dict:
        data = dict(validated_data)
        user_condition_id = data.pop("user_condition", None)
        if user_condition_id is None and existing is not None:
            user_condition_id = existing.user_condition_id
        payload = {
            **data,
            "source_type": ConditionMedication.SOURCE_CONDITION,
            "user_condition_id": user_condition_id,
        }
        if "schedules" in validated_data:
            payload["schedules"] = list(validated_data.get("schedules") or [])
        return payload

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            medication = MedicationPlanService.create_medication_plan(
                user=request.user,
                payload=self._medication_payload(serializer.validated_data),
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(ConditionMedicationSerializer(medication).data, status=status.HTTP_201_CREATED)

    def partial_update(self, request, *args, **kwargs):
        existing = self.get_object()
        serializer = self.get_serializer(existing, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        try:
            medication = MedicationPlanService.update_medication_plan(
                user=request.user,
                medication_id=existing.id,
                payload=self._medication_payload(serializer.validated_data, existing=existing),
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(ConditionMedicationSerializer(medication).data)

    def update(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)

    @action(detail=True, methods=["post"])
    def deactivate(self, request, pk=None):
        existing = self.get_object()
        medication = MedicationPlanService.deactivate_medication_plan(
            user=request.user,
            medication_id=existing.id,
        )
        return Response({"id": medication.id, "is_active": medication.is_active})


class ConditionMedicationScheduleViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ConditionMedicationScheduleSerializer

    def get_queryset(self):
        return ConditionReadService.get_condition_medication_schedules(user=self.request.user)

    @action(detail=False, methods=["get"])
    def today(self, request):
        return Response(ConditionMedicationService.today_dose_list(user=request.user))

    @action(detail=True, methods=["post"])
    def take(self, request, pk=None):
        schedule = self.get_object()
        result = ConditionMedicationService.mark_taken(schedule=schedule)
        log = result.log
        return Response(
            {
                "schedule_id": schedule.id,
                "scheduled_date": str(log.scheduled_date),
                "status": log.status,
                "taken_at": log.taken_at.isoformat() if log.taken_at else None,
                "scheduled_for": log.scheduled_for.isoformat() if log.scheduled_for else None,
                "skip_reason": log.skip_reason,
                "points_applied": log.points_applied,
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"])
    def miss(self, request, pk=None):
        schedule = self.get_object()
        result = ConditionMedicationService.mark_missed(schedule=schedule)
        log = result.log
        return Response(
            {
                "schedule_id": schedule.id,
                "scheduled_date": str(log.scheduled_date),
                "status": log.status,
                "points_applied": log.points_applied,
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"])
    def snooze(self, request, pk=None):
        schedule = self.get_object()
        serializer = ConditionDoseActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = ConditionMedicationService.snooze_dose(
            schedule=schedule,
            snooze_minutes=serializer.validated_data.get("snooze_minutes"),
        )
        log = result.log
        return Response(
            {
                "schedule_id": schedule.id,
                "scheduled_date": str(log.scheduled_date),
                "status": log.status,
                "scheduled_for": result.reminder_at.isoformat() if result.reminder_at else None,
                "points_applied": log.points_applied,
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"])
    def skip(self, request, pk=None):
        schedule = self.get_object()
        serializer = ConditionDoseActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = ConditionMedicationService.skip_dose(
            schedule=schedule,
            reason=serializer.validated_data.get("reason", ""),
        )
        log = result.log
        return Response(
            {
                "schedule_id": schedule.id,
                "scheduled_date": str(log.scheduled_date),
                "status": log.status,
                "skip_reason": log.skip_reason,
                "points_applied": log.points_applied,
            },
            status=status.HTTP_200_OK,
        )


class HealthIndicatorRecordViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = HealthIndicatorRecordSerializer

    def get_queryset(self):
        return ConditionReadService.get_health_indicator_records(
            user=self.request.user,
            user_condition_id=self.request.query_params.get("user_condition"),
        )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user_condition = serializer.validated_data["user_condition"]
        try:
            record = measurement_workflow_service.log_legacy_indicator(
                user=request.user,
                user_condition=user_condition,
                payload=serializer.validated_data,
            )
        except (PermissionError, ValueError) as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        output = self.get_serializer(record)
        return Response(output.data, status=status.HTTP_201_CREATED)
