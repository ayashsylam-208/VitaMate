from django.contrib import admin

from ai_meals.models import (
    AIIngredientMapping,
    MealAnalysisCandidate,
    MealAnalysisComponent,
    MealAnalysisSession,
)


@admin.register(MealAnalysisSession)
class MealAnalysisSessionAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "status", "selected_dish_label", "created_at")
    list_filter = ("status", "meal_type")
    search_fields = ("user__username", "selected_dish_label", "provider_session_id")
    readonly_fields = ("raw_analysis", "image_sha256", "created_at", "updated_at")


admin.site.register(MealAnalysisCandidate)
admin.site.register(MealAnalysisComponent)
admin.site.register(AIIngredientMapping)
