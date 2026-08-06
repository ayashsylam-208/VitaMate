from django.urls import path

from ai_meals.views import (
    AnalyzeMealView,
    FinalizeMealAnalysisView,
    MealAnalysisDetailView,
)


urlpatterns = [
    path("analyze/", AnalyzeMealView.as_view(), name="ai-meal-analyze"),
    path("<uuid:analysis_id>/", MealAnalysisDetailView.as_view(), name="ai-meal-detail"),
    path(
        "<uuid:analysis_id>/confirmation/",
        MealAnalysisDetailView.as_view(),
        name="ai-meal-confirmation",
    ),
    path(
        "<uuid:analysis_id>/finalize/",
        FinalizeMealAnalysisView.as_view(),
        name="ai-meal-finalize",
    ),
]
