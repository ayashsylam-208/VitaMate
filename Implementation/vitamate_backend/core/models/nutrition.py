from django.contrib.auth.models import User
from django.db import models
from django.db.models import Q
from django.utils import timezone

from core.models.common import normalize_food_search_text


class FoodCategory(models.Model):
    code = models.CharField(max_length=80, unique=True)
    name = models.CharField(max_length=120, db_index=True)
    parent = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="children",
    )
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True, db_index=True)

    class Meta:
        ordering = ("sort_order", "name")
        indexes = [
            models.Index(fields=("parent", "sort_order"), name="foodcat_parent_sort_idx"),
        ]

    def __str__(self):
        return self.name


class FoodItem(models.Model):
    TYPE_FOOD = "food"
    TYPE_BEVERAGE = "beverage"
    TYPE_DRINK = "drink"
    ITEM_TYPE_CHOICES = [
        (TYPE_FOOD, "Food"),
        (TYPE_BEVERAGE, "Beverage"),
        (TYPE_DRINK, "Drink"),
    ]
    SOURCE_USDA = "usda"
    SOURCE_MANUAL = "manual"
    SOURCE_AI = "ai"
    SOURCE_CUSTOM = "custom"
    SOURCE_CHOICES = [
        (SOURCE_USDA, "USDA"),
        (SOURCE_MANUAL, "Manual"),
        (SOURCE_AI, "AI"),
        (SOURCE_CUSTOM, "Custom"),
    ]

    name = models.CharField(max_length=100, db_index=True)
    normalized_name = models.CharField(max_length=120, blank=True, default="", db_index=True)
    created_by = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="created_food_items",
    )
    item_type = models.CharField(max_length=20, choices=ITEM_TYPE_CHOICES, default=TYPE_FOOD, db_index=True)
    category = models.CharField(max_length=100, null=True, blank=True)
    meal_tags = models.CharField(
        max_length=140,
        blank=True,
        default="",
        db_index=True,
        help_text="Comma-separated meal slots such as breakfast,lunch,dinner,snack,dessert,drink.",
    )
    primary_category = models.ForeignKey(
        FoodCategory,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="items",
    )
    brand_name = models.CharField(max_length=100, null=True, blank=True)
    normalized_brand_name = models.CharField(max_length=120, blank=True, default="", db_index=True)
    description = models.TextField(null=True, blank=True)
    aliases = models.JSONField(default=list, blank=True)
    barcode = models.CharField(max_length=64, null=True, blank=True)
    source = models.CharField(max_length=30, choices=SOURCE_CHOICES, default=SOURCE_MANUAL)
    source_reference = models.CharField(max_length=255, null=True, blank=True)
    default_serving_size = models.FloatField(default=100)
    default_serving_unit = models.CharField(max_length=20, default="g")
    default_reference_unit = models.CharField(max_length=20, default="g")
    density_g_per_ml = models.FloatField(null=True, blank=True)
    is_hydration_trackable = models.BooleanField(default=False, db_index=True)
    contains_caffeine = models.BooleanField(default=False, db_index=True)
    is_verified = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True, db_index=True)
    search_priority = models.IntegerField(default=0, db_index=True)
    calories_100g = models.IntegerField(default=0)
    protein_100g = models.FloatField(default=0)
    carbs_100g = models.FloatField(default=0)
    fat_100g = models.FloatField(default=0)
    fiber_100g = models.FloatField(default=0)
    sugar_100g = models.FloatField(default=0)
    sodium_mg_100g = models.FloatField(default=0)
    saturated_fat_100g = models.FloatField(default=0)
    trans_fat_100g = models.FloatField(default=0)
    potassium_mg_100g = models.FloatField(default=0)
    cholesterol_mg_100g = models.FloatField(default=0)
    vitamin_c_mg_100g = models.FloatField(default=0)
    serving_label = models.CharField(max_length=50, default="Plate")
    serving_grams = models.IntegerField(default=250)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=("item_type", "is_active"), name="fooditem_type_active_idx"),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=("barcode",),
                condition=~models.Q(barcode__isnull=True) & ~models.Q(barcode=""),
                name="unique_fooditem_nonempty_barcode",
            ),
            models.UniqueConstraint(
                fields=("normalized_name",),
                condition=Q(created_by__isnull=True) & ~Q(normalized_name=""),
                name="unique_global_food_normalized_name",
            ),
        ]

    @property
    def is_drink(self):
        return self.item_type in {self.TYPE_BEVERAGE, self.TYPE_DRINK}

    def save(self, *args, **kwargs):
        self.normalized_name = normalize_food_search_text(self.name)
        self.normalized_brand_name = normalize_food_search_text(self.brand_name)
        update_fields = kwargs.get("update_fields")
        if update_fields is not None:
            update_fields = set(update_fields)
            if "name" in update_fields:
                update_fields.add("normalized_name")
            if "brand_name" in update_fields:
                update_fields.add("normalized_brand_name")
            kwargs["update_fields"] = update_fields
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class FoodItemAlias(models.Model):
    TYPE_COMMON_NAME = "common_name"
    TYPE_BRAND_NAME = "brand_name"
    TYPE_ARABIC_NAME = "arabic_name"
    TYPE_ENGLISH_NAME = "english_name"
    TYPE_MISSPELLING = "misspelling"
    TYPE_SHORT_NAME = "short_name"
    ALIAS_TYPE_CHOICES = [
        (TYPE_COMMON_NAME, "Common name"),
        (TYPE_BRAND_NAME, "Brand name"),
        (TYPE_ARABIC_NAME, "Arabic name"),
        (TYPE_ENGLISH_NAME, "English name"),
        (TYPE_MISSPELLING, "Misspelling"),
        (TYPE_SHORT_NAME, "Short name"),
    ]

    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.CASCADE,
        related_name="alias_records",
    )
    alias = models.CharField(max_length=120, db_index=True)
    normalized_alias = models.CharField(max_length=120, blank=True, default="", db_index=True)
    alias_type = models.CharField(
        max_length=30,
        choices=ALIAS_TYPE_CHOICES,
        default=TYPE_COMMON_NAME,
    )
    is_primary = models.BooleanField(default=False)
    sort_order = models.IntegerField(default=0)

    class Meta:
        ordering = ("food_item__name", "sort_order", "alias")
        indexes = [
            models.Index(fields=("food_item", "is_primary"), name="foodalias_item_primary_idx"),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=("food_item", "normalized_alias", "alias_type"),
                name="unique_fooditem_alias_type",
            )
        ]

    def save(self, *args, **kwargs):
        self.normalized_alias = normalize_food_search_text(self.alias)
        update_fields = kwargs.get("update_fields")
        if update_fields is not None:
            update_fields = set(update_fields)
            if "alias" in update_fields:
                update_fields.add("normalized_alias")
            kwargs["update_fields"] = update_fields
        super().save(*args, **kwargs)

    def __str__(self):
        return self.alias


class FavoriteFood(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="favorite_foods",
    )
    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.CASCADE,
        related_name="favorited_by",
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("-created_at", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "food_item"),
                name="unique_user_favorite_food",
            )
        ]
        indexes = [
            models.Index(
                fields=("user", "created_at"),
                name="favorite_food_user_created_idx",
            )
        ]


class NutritionFacts(models.Model):
    BASIS_PER_100G = "per_100g"
    BASIS_PER_100ML = "per_100ml"
    BASIS_PER_SERVING = "per_serving"
    BASIS_TYPE_CHOICES = [
        (BASIS_PER_100G, "Per 100g"),
        (BASIS_PER_100ML, "Per 100ml"),
        (BASIS_PER_SERVING, "Per serving"),
    ]
    BASIS_UNIT_CHOICES = [
        ("g", "Gram"),
        ("ml", "Milliliter"),
        ("serving", "Serving"),
    ]

    food_item = models.OneToOneField(
        FoodItem,
        on_delete=models.CASCADE,
        related_name="nutrition_facts",
    )
    basis_type = models.CharField(max_length=20, choices=BASIS_TYPE_CHOICES, default=BASIS_PER_100G)
    basis_value = models.FloatField(default=100)
    basis_amount = models.FloatField(default=100)
    basis_unit = models.CharField(max_length=20, choices=BASIS_UNIT_CHOICES, default="g")
    serving_size = models.FloatField(default=100)
    serving_unit = models.CharField(max_length=20, default="g")
    calories_kcal = models.FloatField(default=0)
    protein_g = models.FloatField(default=0)
    carbohydrates_g = models.FloatField(default=0)
    sugars_g = models.FloatField(default=0)
    fiber_g = models.FloatField(default=0)
    fat_g = models.FloatField(default=0)
    saturated_fat_g = models.FloatField(default=0)
    trans_fat_g = models.FloatField(default=0)
    cholesterol_mg = models.FloatField(default=0)
    sodium_mg = models.FloatField(default=0)
    potassium_mg = models.FloatField(default=0)
    calcium_mg = models.FloatField(default=0)
    iron_mg = models.FloatField(default=0)
    magnesium_mg = models.FloatField(default=0)
    zinc_mg = models.FloatField(default=0)
    phosphorus_mg = models.FloatField(default=0)
    vitamin_a_mcg = models.FloatField(default=0)
    vitamin_c_mg = models.FloatField(default=0)
    vitamin_d_mcg = models.FloatField(default=0)
    vitamin_b12_mcg = models.FloatField(default=0)
    folate_mcg = models.FloatField(default=0)
    monounsaturated_fat_g = models.FloatField(default=0)
    polyunsaturated_fat_g = models.FloatField(default=0)
    added_sugars_g = models.FloatField(default=0)
    water_g = models.FloatField(default=0)
    caffeine_mg = models.FloatField(default=0)
    vitamin_e_mg = models.FloatField(default=0)
    vitamin_k_mcg = models.FloatField(default=0)
    vitamin_b1_mg = models.FloatField(default=0)
    vitamin_b2_mg = models.FloatField(default=0)
    vitamin_b3_mg = models.FloatField(default=0)
    vitamin_b6_mg = models.FloatField(default=0)
    source_name = models.CharField(max_length=120, blank=True)
    source_reference = models.CharField(max_length=255, blank=True)
    confidence_score = models.FloatField(null=True, blank=True)
    last_verified_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=(
                    Q(basis_value__gt=0)
                    & Q(basis_amount__gt=0)
                    & Q(serving_size__gt=0)
                ),
                name="nutrition_facts_positive_basis",
            ),
            models.CheckConstraint(
                condition=(
                    Q(basis_type="per_100g", basis_unit="g")
                    | Q(basis_type="per_100ml", basis_unit="ml")
                    | Q(basis_type="per_serving", basis_unit="serving")
                ),
                name="nutrition_facts_basis_consistent",
            ),
            models.CheckConstraint(
                condition=(
                    Q(calories_kcal__gte=0)
                    & Q(protein_g__gte=0)
                    & Q(carbohydrates_g__gte=0)
                    & Q(sugars_g__gte=0)
                    & Q(fiber_g__gte=0)
                    & Q(fat_g__gte=0)
                    & Q(sodium_mg__gte=0)
                ),
                name="nutrition_facts_core_nonnegative",
            ),
            models.CheckConstraint(
                condition=(
                    Q(confidence_score__isnull=True)
                    | (Q(confidence_score__gte=0) & Q(confidence_score__lte=1))
                ),
                name="nutrition_facts_confidence_range",
            ),
        ]

    def save(self, *args, **kwargs):
        expected_units = {
            self.BASIS_PER_100G: "g",
            self.BASIS_PER_100ML: "ml",
            self.BASIS_PER_SERVING: "serving",
        }
        self.basis_unit = expected_units.get(self.basis_type, self.basis_unit)
        update_fields = kwargs.get("update_fields")
        if update_fields is not None and "basis_type" in update_fields:
            kwargs["update_fields"] = set(update_fields) | {"basis_unit"}
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.food_item.name} nutrition facts"


class Nutrient(models.Model):
    CATEGORY_MACRO = "macro"
    CATEGORY_VITAMIN = "vitamin"
    CATEGORY_MINERAL = "mineral"
    CATEGORY_STIMULANT = "stimulant"
    CATEGORY_OTHER = "other"
    CATEGORY_CHOICES = [
        (CATEGORY_MACRO, "Macro"),
        (CATEGORY_VITAMIN, "Vitamin"),
        (CATEGORY_MINERAL, "Mineral"),
        (CATEGORY_STIMULANT, "Stimulant"),
        (CATEGORY_OTHER, "Other"),
    ]

    code = models.CharField(max_length=80, unique=True)
    name = models.CharField(max_length=120)
    unit = models.CharField(max_length=30)
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES, default=CATEGORY_OTHER)
    is_core = models.BooleanField(default=False)

    class Meta:
        ordering = ("category", "name")

    def __str__(self):
        return f"{self.name} ({self.unit})"


class ItemNutrientValue(models.Model):
    item = models.ForeignKey(
        FoodItem,
        on_delete=models.CASCADE,
        related_name="nutrient_values",
    )
    nutrient = models.ForeignKey(
        Nutrient,
        on_delete=models.PROTECT,
        related_name="item_values",
    )
    amount = models.FloatField(default=0)
    basis_amount = models.FloatField(default=100)
    basis_unit = models.CharField(max_length=20, default="g")

    class Meta:
        ordering = ("item__name", "nutrient__category", "nutrient__name")
        constraints = [
            models.UniqueConstraint(
                fields=("item", "nutrient", "basis_amount", "basis_unit"),
                name="unique_item_nutrient_basis",
            )
        ]

    def __str__(self):
        return f"{self.item.name}: {self.nutrient.code}={self.amount}"


class NutritionServingOption(models.Model):
    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.CASCADE,
        related_name="serving_options",
    )
    name = models.CharField(max_length=80)
    amount = models.FloatField(default=1)
    unit = models.CharField(max_length=20)
    grams_equivalent = models.FloatField(null=True, blank=True)
    milliliters_equivalent = models.FloatField(null=True, blank=True)
    is_default = models.BooleanField(default=False)
    sort_order = models.IntegerField(default=0)

    class Meta:
        ordering = ("food_item__name", "sort_order", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("food_item",),
                condition=Q(is_default=True),
                name="unique_default_serving_per_food",
            ),
            models.CheckConstraint(
                condition=Q(amount__gt=0),
                name="nutrition_serving_amount_positive",
            ),
            models.CheckConstraint(
                condition=(
                    (Q(grams_equivalent__isnull=True) | Q(grams_equivalent__gte=0))
                    & (
                        Q(milliliters_equivalent__isnull=True)
                        | Q(milliliters_equivalent__gte=0)
                    )
                ),
                name="nutrition_serving_equivalents_nonnegative",
            ),
        ]

    def __str__(self):
        return f"{self.food_item.name} - {self.name}"


class MealLog(models.Model):
    MEAL_TYPES = [
        ("breakfast", "Breakfast"),
        ("lunch", "Lunch"),
        ("dinner", "Dinner"),
        ("snack", "Snack"),
        ("dessert", "Dessert"),
        ("drink", "Drink"),
        ("unknown", "Unknown"),
    ]
    SOURCE_MANUAL = "manual"
    SOURCE_BARCODE = "barcode"
    SOURCE_FAVORITE = "favorite"
    SOURCE_AI = "ai"
    SOURCE_HABIT_SYNC = "habit_sync"
    SOURCE_CHOICES = [
        (SOURCE_MANUAL, "Manual"),
        (SOURCE_BARCODE, "Barcode"),
        (SOURCE_FAVORITE, "Favorite"),
        (SOURCE_AI, "AI"),
        (SOURCE_HABIT_SYNC, "Habit sync"),
    ]

    ORIGIN_NUTRITION = "nutrition"
    ORIGIN_HABITS = "habits"
    ORIGIN_HYDRATION = "hydration"
    SOURCE_TYPE_DIRECT = "direct_user_entry"
    SOURCE_TYPE_HABIT_PROJECTION = "habit_projection"
    SOURCE_TYPE_TRACKER_PROJECTION = "tracker_projection"
    SOURCE_TYPE_IMPORTED = "imported"
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    food = models.ForeignKey(
        FoodItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        help_text="Primary food for legacy single-component meal logs.",
    )
    display_name = models.CharField(max_length=160, blank=True, default="")
    is_composite = models.BooleanField(default=False, db_index=True)
    meal_type = models.CharField(max_length=20, choices=MEAL_TYPES)
    quantity_grams = models.FloatField(default=100.0, help_text="Quantity in grams")
    quantity = models.FloatField(default=1)
    unit = models.CharField(max_length=20, default="g")
    grams_consumed = models.FloatField(null=True, blank=True)
    milliliters_consumed = models.FloatField(null=True, blank=True)
    servings_consumed = models.FloatField(null=True, blank=True)
    serving_option = models.ForeignKey(
        NutritionServingOption,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="meal_logs",
    )
    serving_label_snapshot = models.CharField(max_length=80, blank=True, default="")
    consumed_at = models.DateTimeField(null=True, blank=True)
    snapshot_calories_kcal = models.FloatField(null=True, blank=True)
    snapshot_protein_g = models.FloatField(null=True, blank=True)
    snapshot_carbohydrates_g = models.FloatField(null=True, blank=True)
    snapshot_sugars_g = models.FloatField(null=True, blank=True)
    snapshot_fiber_g = models.FloatField(null=True, blank=True)
    snapshot_fat_g = models.FloatField(null=True, blank=True)
    snapshot_saturated_fat_g = models.FloatField(null=True, blank=True)
    snapshot_trans_fat_g = models.FloatField(null=True, blank=True)
    snapshot_cholesterol_mg = models.FloatField(null=True, blank=True)
    snapshot_sodium_mg = models.FloatField(null=True, blank=True)
    snapshot_potassium_mg = models.FloatField(null=True, blank=True)
    snapshot_calcium_mg = models.FloatField(null=True, blank=True)
    snapshot_iron_mg = models.FloatField(null=True, blank=True)
    snapshot_magnesium_mg = models.FloatField(null=True, blank=True)
    snapshot_zinc_mg = models.FloatField(null=True, blank=True)
    snapshot_phosphorus_mg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_a_mcg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_c_mg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_d_mcg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_b12_mcg = models.FloatField(null=True, blank=True)
    snapshot_folate_mcg = models.FloatField(null=True, blank=True)
    snapshot_monounsaturated_fat_g = models.FloatField(null=True, blank=True)
    snapshot_polyunsaturated_fat_g = models.FloatField(null=True, blank=True)
    snapshot_added_sugars_g = models.FloatField(null=True, blank=True)
    snapshot_water_g = models.FloatField(null=True, blank=True)
    snapshot_caffeine_mg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_e_mg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_k_mcg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_b1_mg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_b2_mg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_b3_mg = models.FloatField(null=True, blank=True)
    snapshot_vitamin_b6_mg = models.FloatField(null=True, blank=True)
    notes = models.TextField(blank=True)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default=SOURCE_MANUAL)
    origin_domain = models.CharField(max_length=24, blank=True, default=ORIGIN_NUTRITION, db_index=True)
    origin_record_id = models.CharField(max_length=64, blank=True, default="")
    correlation_id = models.CharField(max_length=64, blank=True, default="", db_index=True)
    source_type = models.CharField(max_length=32, blank=True, default=SOURCE_TYPE_DIRECT, db_index=True)
    source_ref = models.CharField(max_length=120, blank=True, default="", db_index=True)
    projection_version = models.PositiveSmallIntegerField(default=1)
    reward_owner_domain = models.CharField(max_length=24, blank=True, default="nutrition")
    finalization_key = models.CharField(max_length=120, blank=True, default="", db_index=True)
    is_fast_food = models.BooleanField(default=False, db_index=True)
    quality_tags = models.JSONField(default=list, blank=True)
    date = models.DateField(default=timezone.localdate)

    class Meta:
        indexes = [
            models.Index(fields=("user", "source_type", "source_ref"), name="meal_log_source_ref_idx"),
            models.Index(fields=("origin_domain", "origin_record_id"), name="meal_log_origin_idx"),
            models.Index(fields=("user", "is_fast_food", "date"), name="meal_log_fast_food_idx"),
            models.Index(fields=("user", "consumed_at"), name="meal_log_consumed_at_idx"),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=("user", "source_type", "source_ref"),
                condition=~Q(source_ref=""),
                name="unique_meal_log_projection_ref",
            ),
            models.UniqueConstraint(
                fields=("user", "finalization_key"),
                condition=~Q(finalization_key=""),
                name="unique_meal_finalization_key",
            ),
        ]

    @property
    def total_calories(self):
        if self.snapshot_calories_kcal is not None:
            return int(round(self.snapshot_calories_kcal))
        if self.food is None:
            return 0
        return int((self.food.calories_100g / 100.0) * self.quantity_grams)


class MealLogComponent(models.Model):
    meal_log = models.ForeignKey(
        MealLog,
        on_delete=models.CASCADE,
        related_name="components",
    )
    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.PROTECT,
        related_name="meal_log_components",
    )
    display_name_snapshot = models.CharField(max_length=160)
    quantity_value = models.DecimalField(max_digits=10, decimal_places=3)
    quantity_unit = models.CharField(max_length=20, default="g")
    resolved_grams = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    resolved_milliliters = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        null=True,
        blank=True,
    )
    nutrition_snapshot = models.JSONField(default=dict)
    source_label = models.CharField(max_length=160, blank=True, default="")
    is_user_confirmed = models.BooleanField(default=True)
    sort_order = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("sort_order", "id")
        indexes = [
            models.Index(fields=("meal_log", "sort_order"), name="meal_component_order_idx"),
            models.Index(fields=("food_item",), name="meal_component_food_idx"),
        ]
        constraints = [
            models.CheckConstraint(
                condition=Q(quantity_value__gt=0),
                name="meal_component_quantity_positive",
            ),
            models.CheckConstraint(
                condition=(
                    Q(resolved_grams__gt=0)
                    | Q(resolved_milliliters__gt=0)
                ),
                name="meal_component_has_resolved_amount",
            ),
            models.CheckConstraint(
                condition=(
                    Q(confidence_score__isnull=True)
                    | (Q(confidence_score__gte=0) & Q(confidence_score__lte=1))
                ),
                name="meal_component_confidence_range",
            ),
        ]

    def __str__(self):
        return f"{self.meal_log_id}: {self.display_name_snapshot}"


class WaterLog(models.Model):
    BEVERAGE_WATER = "water"
    BEVERAGE_TEA = "tea"
    BEVERAGE_COFFEE = "coffee"
    BEVERAGE_JUICE = "juice"
    BEVERAGE_MILK = "milk"
    BEVERAGE_SODA = "soda"
    BEVERAGE_SMOOTHIE = "smoothie"
    BEVERAGE_OTHER = "other"
    BEVERAGE_CHOICES = [
        (BEVERAGE_WATER, "Water"),
        (BEVERAGE_TEA, "Tea"),
        (BEVERAGE_COFFEE, "Coffee"),
        (BEVERAGE_JUICE, "Juice"),
        (BEVERAGE_MILK, "Milk"),
        (BEVERAGE_SODA, "Soda"),
        (BEVERAGE_SMOOTHIE, "Smoothie"),
        (BEVERAGE_OTHER, "Other"),
    ]
    ORIGIN_HYDRATION = "hydration"
    ORIGIN_HABITS = "habits"
    ORIGIN_NUTRITION = "nutrition"
    SOURCE_TYPE_DIRECT = "direct_user_entry"
    SOURCE_TYPE_HABIT_PROJECTION = "habit_projection"
    SOURCE_TYPE_TRACKER_PROJECTION = "tracker_projection"
    SOURCE_TYPE_IMPORTED = "imported"

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="water_logs",
    )
    drink_item = models.ForeignKey(
        FoodItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="drink_water_logs",
    )
    linked_meal_log = models.ForeignKey(
        MealLog,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="water_logs",
    )
    beverage_type = models.CharField(
        max_length=30,
        choices=BEVERAGE_CHOICES,
        default=BEVERAGE_WATER,
    )
    beverage_name = models.CharField(max_length=100, blank=True, default="Water")
    amount_liter = models.FloatField(help_text="Quantity in liters")
    caffeine_mg = models.FloatField(default=0)
    consumed_at = models.DateTimeField(default=timezone.now, db_index=True)
    origin_domain = models.CharField(max_length=24, blank=True, default=ORIGIN_HYDRATION, db_index=True)
    origin_record_id = models.CharField(max_length=64, blank=True, default="")
    correlation_id = models.CharField(max_length=64, blank=True, default="", db_index=True)
    source_type = models.CharField(max_length=32, blank=True, default=SOURCE_TYPE_DIRECT, db_index=True)
    source_ref = models.CharField(max_length=120, blank=True, default="", db_index=True)
    projection_version = models.PositiveSmallIntegerField(default=1)
    reward_owner_domain = models.CharField(max_length=24, blank=True, default="hydration")
    date = models.DateField(default=timezone.localdate)

    class Meta:
        indexes = [
            models.Index(fields=("user", "consumed_at"), name="water_log_consumed_at_idx"),
            models.Index(fields=("user", "source_type", "source_ref"), name="water_log_source_ref_idx"),
            models.Index(fields=("origin_domain", "origin_record_id"), name="water_log_origin_idx"),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=("user", "source_type", "source_ref"),
                condition=~Q(source_ref=""),
                name="unique_water_log_projection_ref",
            )
        ]
