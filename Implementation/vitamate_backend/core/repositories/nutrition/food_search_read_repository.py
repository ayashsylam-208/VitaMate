from __future__ import annotations

from django.db.models import Case, Exists, IntegerField, OuterRef, Q, Value, When

from core.models import FoodItem, FoodItemAlias, normalize_food_search_text
from core.repositories.food_item_repository import NutritionCatalogRepository


class FoodSearchReadRepository:
    MAX_LIMIT = 100

    @classmethod
    def search_accessible(
        cls,
        *,
        user,
        q: str = "",
        item_type: str | None = None,
        category: str | None = None,
        meal_slot: str | None = None,
        contains_caffeine=None,
        is_hydration_trackable=None,
        limit=None,
        include_inactive: bool = False,
        own_only: bool = False,
        offset=None,
    ):
        queryset = NutritionCatalogRepository.accessible_to_user(
            user=user,
            include_inactive=include_inactive,
        ).select_related("primary_category", "nutrition_facts").prefetch_related(
            "serving_options"
        )

        if own_only:
            queryset = queryset.filter(created_by=user)

        queryset = cls._apply_item_type_filter(queryset, item_type)
        queryset = cls._apply_category_filter(queryset, category)
        queryset = cls._apply_meal_slot_filter(queryset, meal_slot)
        queryset = cls._apply_bool_filter(queryset, "contains_caffeine", contains_caffeine)
        queryset = cls._apply_bool_filter(
            queryset,
            "is_hydration_trackable",
            is_hydration_trackable,
        )

        normalized_query = normalize_food_search_text(q)
        if normalized_query:
            queryset = cls._apply_query_filter(queryset, normalized_query, q)
        else:
            queryset = queryset.order_by(
                "-is_verified",
                "-search_priority",
                "name",
                "id",
            )

        parsed_limit = cls._parse_limit(limit)
        parsed_offset = cls._parse_offset(offset)
        if parsed_limit is not None:
            queryset = queryset[parsed_offset : parsed_offset + parsed_limit]
        elif parsed_offset:
            queryset = queryset[parsed_offset:]
        return queryset

    @classmethod
    def find_matching_beverage(
        cls,
        *,
        user,
        beverage_name: str,
        beverage_type: str,
    ):
        beverages = cls.search_accessible(
            user=user,
            item_type=FoodItem.TYPE_BEVERAGE,
            include_inactive=False,
        )
        if beverage_name:
            exact_name = beverages.filter(name__iexact=beverage_name).first()
            if exact_name is not None:
                return exact_name

        if beverage_type:
            category_match = beverages.filter(category__icontains=beverage_type).first()
            if category_match is not None:
                return category_match
            primary_category_match = beverages.filter(
                primary_category__code__icontains=beverage_type,
            ).first()
            if primary_category_match is not None:
                return primary_category_match
            name_match = beverages.filter(name__icontains=beverage_type).first()
            if name_match is not None:
                return name_match

        return None

    @staticmethod
    def _apply_item_type_filter(queryset, item_type):
        if not item_type:
            return queryset
        normalized_type = str(item_type).strip().lower()
        if normalized_type in {FoodItem.TYPE_BEVERAGE, FoodItem.TYPE_DRINK}:
            return queryset.filter(
                Q(item_type__in=[FoodItem.TYPE_BEVERAGE, FoodItem.TYPE_DRINK])
                | Q(is_hydration_trackable=True)
            )
        return queryset.filter(item_type=normalized_type)

    @staticmethod
    def _apply_category_filter(queryset, category):
        if not category:
            return queryset
        raw_category = str(category).strip()
        normalized_code = normalize_food_search_text(raw_category).replace(" ", "_")
        filters = (
            Q(category__iexact=raw_category)
            | Q(primary_category__code__iexact=normalized_code)
            | Q(primary_category__name__iexact=raw_category)
        )
        if raw_category.isdigit():
            filters |= Q(primary_category_id=int(raw_category))
        return queryset.filter(filters)

    @staticmethod
    def _apply_meal_slot_filter(queryset, meal_slot):
        if not meal_slot:
            return queryset
        normalized = str(meal_slot).strip().lower().replace(" ", "_")
        valid_slots = {"breakfast", "lunch", "dinner", "snack", "dessert", "drink"}
        if normalized not in valid_slots:
            return queryset
        if normalized == "drink":
            return queryset.filter(
                Q(meal_tags__icontains="drink")
                | Q(item_type__in=[FoodItem.TYPE_BEVERAGE, FoodItem.TYPE_DRINK])
                | Q(is_hydration_trackable=True)
            )
        return queryset.filter(meal_tags__icontains=normalized)

    @staticmethod
    def _apply_bool_filter(queryset, field_name, raw_value):
        parsed = FoodSearchReadRepository._parse_bool(raw_value)
        if parsed is None:
            return queryset
        return queryset.filter(**{field_name: parsed})

    @staticmethod
    def _apply_query_filter(queryset, normalized_query, raw_query):
        alias_base = FoodItemAlias.objects.filter(food_item_id=OuterRef("pk"))
        queryset = queryset.annotate(
            alias_exact_match=Exists(alias_base.filter(normalized_alias=normalized_query)),
            alias_prefix_match=Exists(
                alias_base.filter(normalized_alias__startswith=normalized_query),
            ),
            alias_contains_match=Exists(
                alias_base.filter(normalized_alias__contains=normalized_query),
            ),
        )
        queryset = queryset.filter(
            Q(normalized_name__contains=normalized_query)
            | Q(name__icontains=raw_query)
            | Q(normalized_brand_name__contains=normalized_query)
            | Q(brand_name__icontains=raw_query)
            | Q(category__icontains=raw_query)
            | Q(primary_category__name__icontains=raw_query)
            | Q(primary_category__code__icontains=normalized_query.replace(" ", "_"))
            | Q(alias_exact_match=True)
            | Q(alias_prefix_match=True)
            | Q(alias_contains_match=True)
        )
        return queryset.annotate(
            search_rank=Case(
                When(normalized_name=normalized_query, then=Value(1000)),
                When(alias_exact_match=True, then=Value(900)),
                When(normalized_brand_name=normalized_query, then=Value(850)),
                When(normalized_name__startswith=normalized_query, then=Value(800)),
                When(alias_prefix_match=True, then=Value(700)),
                When(normalized_name__contains=normalized_query, then=Value(600)),
                When(normalized_brand_name__contains=normalized_query, then=Value(550)),
                When(alias_contains_match=True, then=Value(500)),
                default=Value(0),
                output_field=IntegerField(),
            )
        ).order_by(
            "-search_rank",
            "-is_verified",
            "-search_priority",
            "name",
            "id",
        )

    @staticmethod
    def _parse_bool(value):
        if value is None or value == "":
            return None
        if isinstance(value, bool):
            return value
        normalized = str(value).strip().lower()
        if normalized in {"1", "true", "yes", "y", "on"}:
            return True
        if normalized in {"0", "false", "no", "n", "off"}:
            return False
        return None

    @classmethod
    def _parse_limit(cls, value):
        if value in (None, ""):
            return None
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return None
        if parsed <= 0:
            return None
        return min(parsed, cls.MAX_LIMIT)

    @staticmethod
    def _parse_offset(value):
        if value in (None, ""):
            return 0
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return 0
        return max(parsed, 0)
