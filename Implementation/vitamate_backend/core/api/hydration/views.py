from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.utils.dateparse import parse_date, parse_datetime
from django.utils import timezone

from core.api.hydration.serializers import WaterLogSerializer
from core.models import WaterLog
from core.services.hydration.water_service import WaterService


class WaterLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = WaterLogSerializer

    def get_queryset(self):
        query_date = self._query_date()
        start_dt = self._query_datetime("from")
        end_dt = self._query_datetime("to")
        if start_dt is not None or end_dt is not None:
            return WaterService.get_water_logs(
                user=self.request.user,
                start=start_dt,
                end=end_dt,
            )
        return WaterService.get_water_logs(
            user=self.request.user,
            on_date=query_date or timezone.localdate(),
        )

    def _query_date(self):
        raw = self.request.query_params.get("date")
        if not raw:
            return None
        return parse_date(raw)

    def _query_datetime(self, key):
        raw = self.request.query_params.get(key)
        if not raw:
            return None
        parsed_date = parse_date(raw)
        if parsed_date is not None and len(raw) <= 10:
            start, end = WaterService.get_day_bounds(parsed_date)
            return end if key == "to" else start
        parsed = parse_datetime(raw)
        if parsed is None:
            return None
        if timezone.is_naive(parsed):
            parsed = timezone.make_aware(parsed, timezone.get_current_timezone())
        return parsed

    def perform_create(self, serializer):
        data = serializer.validated_data
        log = WaterService.log_water(
            user=self.request.user,
            amount_liter=data.get("amount_liter"),
            amount_ml=data.get("amount_ml"),
            beverage_type=data.get("beverage_type", WaterLog.BEVERAGE_WATER),
            beverage_name=data.get("beverage_name", "Water"),
            food_item=data.get("food_item"),
            drink_item=data.get("drink_item"),
            custom_beverage=data.get("custom_beverage"),
            save_for_reuse=data.get("save_for_reuse", True),
            caffeine_mg=data.get("caffeine_mg", 0),
            consumed_at=data.get("consumed_at"),
        )
        serializer.instance = log

    def perform_update(self, serializer):
        data = serializer.validated_data
        log = WaterService.update_water_log(
            serializer.instance,
            amount_liter=data.get("amount_liter", serializer.instance.amount_liter),
            amount_ml=data.get("amount_ml"),
            beverage_type=data.get("beverage_type", serializer.instance.beverage_type),
            beverage_name=data.get("beverage_name", serializer.instance.beverage_name),
            food_item=data.get("food_item", serializer.instance.food_item),
            drink_item=data.get("drink_item", serializer.instance.drink_item),
            custom_beverage=data.get("custom_beverage"),
            save_for_reuse=data.get("save_for_reuse", True),
            caffeine_mg=data.get("caffeine_mg", serializer.instance.caffeine_mg),
            consumed_at=data.get("consumed_at", serializer.instance.consumed_at),
        )
        serializer.instance = log

    def perform_destroy(self, instance):
        WaterService.delete_water_log(instance)


class HydrationLogViewSet(WaterLogViewSet):
    """New route alias for the Hydration bounded API."""

    def get_queryset(self):
        params = self.request.query_params
        if not any(params.get(key) for key in ("date", "from", "to")):
            return WaterService.get_water_logs(user=self.request.user)
        return super().get_queryset()

    def list(self, request, *args, **kwargs):
        if not any(request.query_params.get(key) for key in ("page", "page_size", "cursor")):
            return super().list(request, *args, **kwargs)

        queryset = self.filter_queryset(self.get_queryset())
        page_size = self._positive_int(request.query_params.get("page_size"), default=50)
        page_size = min(page_size, 100)
        cursor = request.query_params.get("cursor")
        if cursor not in (None, ""):
            offset = self._positive_int(cursor, default=0, allow_zero=True)
            page = (offset // page_size) + 1
        else:
            page = self._positive_int(request.query_params.get("page"), default=1)
            offset = (page - 1) * page_size

        rows = list(queryset[offset : offset + page_size + 1])
        has_next = len(rows) > page_size
        page_rows = rows[:page_size]
        serializer = self.get_serializer(page_rows, many=True)
        return Response(
            {
                "data": serializer.data,
                "pagination": {
                    "page": page,
                    "page_size": page_size,
                    "count": queryset.count(),
                    "next_page": page + 1 if has_next else None,
                    "previous_page": page - 1 if page > 1 else None,
                    "next_cursor": str(offset + page_size) if has_next else None,
                    "previous_cursor": str(max(offset - page_size, 0)) if offset > 0 else None,
                },
            }
        )

    @staticmethod
    def _positive_int(value, *, default, allow_zero=False):
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return default
        minimum = 0 if allow_zero else 1
        return parsed if parsed >= minimum else default
