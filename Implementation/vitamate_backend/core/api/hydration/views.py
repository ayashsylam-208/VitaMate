from datetime import date

from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from core.api.hydration.serializers import WaterLogSerializer
from core.models import WaterLog
from core.services.hydration.water_service import WaterService


class WaterLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = WaterLogSerializer

    def get_queryset(self):
        return WaterService.get_water_logs(
            user=self.request.user,
            on_date=date.today(),
        )

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
        )
        serializer.instance = log

    def perform_destroy(self, instance):
        WaterService.delete_water_log(instance)
