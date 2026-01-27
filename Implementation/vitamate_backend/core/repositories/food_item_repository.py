from core.models import FoodItem


class FoodItemRepository:
    @staticmethod
    def create_item(**data):
        return FoodItem.objects.create(**data)
