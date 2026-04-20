from __future__ import annotations

from django.db.models import Q
from django.db import transaction

from core.models import FoodCategory, FoodItem, FoodItemAlias, NutritionFacts, NutritionServingOption, normalize_food_search_text


class NutritionCatalogRepository:
    @staticmethod
    def create_item(**data):
        return FoodItem.objects.create(**data)

    @staticmethod
    def accessible_to_user(*, user, include_inactive=False):
        queryset = FoodItem.objects.filter(Q(created_by__isnull=True) | Q(created_by=user))
        if not include_inactive:
            queryset = queryset.filter(is_active=True)
        return queryset.distinct()

    @classmethod
    @transaction.atomic
    def create_item_aggregate(
        cls,
        *,
        item_data: dict,
        facts_data: dict,
        serving_options_data: list[dict],
    ):
        item = cls.create_item(**item_data)
        NutritionFacts.objects.create(food_item=item, **facts_data)
        cls.replace_serving_options(item=item, serving_options_data=serving_options_data)
        cls.sync_alias_records(item=item)
        return item

    @classmethod
    @transaction.atomic
    def update_item_aggregate(
        cls,
        *,
        item,
        item_data: dict,
        facts_data: dict | None = None,
        serving_options_data: list[dict] | None = None,
    ):
        for field, value in item_data.items():
            setattr(item, field, value)
        item.save()

        cls.sync_alias_records(item=item)

        if facts_data is not None:
            facts, _ = NutritionFacts.objects.get_or_create(food_item=item)
            for field, value in facts_data.items():
                setattr(facts, field, value)
            facts.save()

        if serving_options_data is not None:
            cls.replace_serving_options(item=item, serving_options_data=serving_options_data)

        return item

    @staticmethod
    def replace_serving_options(*, item, serving_options_data: list[dict]):
        item.serving_options.all().delete()
        for index, option in enumerate(serving_options_data):
            normalized = dict(option)
            normalized.pop("food_item", None)
            sort_order = normalized.pop("sort_order", index)
            NutritionServingOption.objects.create(
                food_item=item,
                sort_order=sort_order,
                **normalized,
            )

    @staticmethod
    def sync_alias_records(*, item):
        NutritionCatalogRepository.upsert_alias_record(
            item=item,
            alias=item.name,
            alias_type=FoodItemAlias.TYPE_COMMON_NAME,
            is_primary=True,
            sort_order=0,
        )
        if item.brand_name:
            NutritionCatalogRepository.upsert_alias_record(
                item=item,
                alias=item.brand_name,
                alias_type=FoodItemAlias.TYPE_BRAND_NAME,
                is_primary=False,
                sort_order=10,
            )
        aliases = item.aliases if isinstance(item.aliases, list) else []
        for index, alias in enumerate(aliases, start=20):
            NutritionCatalogRepository.upsert_alias_record(
                item=item,
                alias=alias,
                alias_type=FoodItemAlias.TYPE_COMMON_NAME,
                is_primary=False,
                sort_order=index,
            )

    @staticmethod
    def upsert_alias_record(
        *,
        item,
        alias,
        alias_type: str,
        is_primary: bool,
        sort_order: int,
    ):
        normalized_alias = normalize_food_search_text(alias)
        if not normalized_alias:
            return None
        alias_record, _ = FoodItemAlias.objects.update_or_create(
            food_item=item,
            normalized_alias=normalized_alias,
            alias_type=alias_type,
            defaults={
                "alias": str(alias).strip(),
                "is_primary": is_primary,
                "sort_order": sort_order,
            },
        )
        return alias_record

    @staticmethod
    def resolve_category_by_legacy_name(raw_category: str):
        if not raw_category:
            return None
        category_code = normalize_food_search_text(raw_category).replace(" ", "_")
        category = FoodCategory.objects.filter(code__iexact=category_code).first()
        if category is None:
            category = FoodCategory.objects.filter(name__iexact=raw_category).first()
        return category

    @staticmethod
    def get_accessible_item_by_id(*, user, food_item_id: int, include_inactive: bool = True):
        queryset = NutritionCatalogRepository.accessible_to_user(
            user=user,
            include_inactive=include_inactive,
        )
        return queryset.filter(id=food_item_id).first()

    @staticmethod
    def get_global_item_by_name(*, name: str, item_type: str | None = None):
        queryset = FoodItem.objects.filter(created_by__isnull=True, name__iexact=name)
        if item_type:
            queryset = queryset.filter(item_type=item_type)
        return queryset.first()

    @staticmethod
    def nutrition_facts_queryset():
        return NutritionFacts.objects.select_related("food_item").all().order_by("food_item__name")

    @staticmethod
    def serving_options_queryset():
        return NutritionServingOption.objects.select_related("food_item").all().order_by(
            "food_item__name",
            "sort_order",
            "id",
        )

    @staticmethod
    def create_nutrition_facts(**data):
        return NutritionFacts.objects.create(**data)

    @staticmethod
    def update_nutrition_facts(instance, **data):
        for field, value in data.items():
            setattr(instance, field, value)
        instance.save()
        return instance

    @staticmethod
    def create_serving_option(**data):
        return NutritionServingOption.objects.create(**data)

    @staticmethod
    def update_serving_option(instance, **data):
        for field, value in data.items():
            setattr(instance, field, value)
        instance.save()
        return instance

    @staticmethod
    def delete_nutrition_facts(instance):
        instance.delete()

    @staticmethod
    def delete_serving_option(instance):
        instance.delete()


class FoodItemRepository(NutritionCatalogRepository):
    pass
