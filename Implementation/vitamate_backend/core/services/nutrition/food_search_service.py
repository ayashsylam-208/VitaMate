from __future__ import annotations

from core.repositories.food_search_read_repository import FoodSearchReadRepository


class FoodSearchService:
    DEFAULT_AUTOCOMPLETE_LIMIT = 8

    @classmethod
    def search(
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
        return FoodSearchReadRepository.search_accessible(
            user=user,
            q=q,
            item_type=item_type,
            category=category,
            meal_slot=meal_slot,
            contains_caffeine=contains_caffeine,
            is_hydration_trackable=is_hydration_trackable,
            include_inactive=include_inactive,
            own_only=own_only,
            limit=limit,
            offset=offset,
        )

    @classmethod
    def autocomplete(cls, **kwargs):
        kwargs.setdefault("limit", cls.DEFAULT_AUTOCOMPLETE_LIMIT)
        return cls.search(**kwargs)

    @staticmethod
    def find_matching_beverage(*, user, beverage_name, beverage_type):
        return FoodSearchReadRepository.find_matching_beverage(
            user=user,
            beverage_name=beverage_name,
            beverage_type=beverage_type,
        )
