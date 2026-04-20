from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from core.views import (
    MealLogViewSet, WaterLogViewSet, MedicineViewSet,
    StepLogViewSet, ActivityLogViewSet, SleepLogViewSet,
    HabitViewSet, FoodItemViewSet, ExerciseViewSet,
    DashboardView, HealthCheckView, NutritionFactsViewSet,
    NutritionServingOptionViewSet, StatsHistoryView,
)
from core.chronic_views import (
    ConditionMedicationViewSet,
    ConditionMedicationScheduleViewSet,
    ConditionTypeViewSet,
    HealthIndicatorRecordViewSet,
    UserConditionViewSet,
)
from core.constraint_views import (
    ConstraintResolutionRunListView,
    HealthConstraintRecomputeView,
    HealthConstraintsView,
)
from core.medication_views import MedicationViewSet
from users.views import RegisterView, ManageUserView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

# Routers
router = DefaultRouter()
chronic_router = DefaultRouter()
router.register(r'meals', MealLogViewSet, basename='meal')
router.register(r'foods', FoodItemViewSet, basename='food')
router.register(r'nutrition-facts', NutritionFactsViewSet, basename='nutrition-facts')
router.register(r'nutrition-serving-options', NutritionServingOptionViewSet, basename='nutrition-serving-option')
router.register(r'water', WaterLogViewSet, basename='water')
router.register(r'medicines', MedicineViewSet, basename='medicine')
router.register(r'steps', StepLogViewSet, basename='steps')
router.register(r'activities', ActivityLogViewSet, basename='activity')
router.register(r'sleep', SleepLogViewSet, basename='sleep')
router.register(r'habits', HabitViewSet, basename='habit')
router.register(r'exercises', ExerciseViewSet, basename='exercise')
router.register(r'condition-types', ConditionTypeViewSet, basename='condition-type')
router.register(r'user-conditions', UserConditionViewSet, basename='user-condition')
router.register(r'condition-medications', ConditionMedicationViewSet, basename='condition-medication')
router.register(r'medications', MedicationViewSet, basename='medication-plan')
router.register(
    r'condition-medication-schedules',
    ConditionMedicationScheduleViewSet,
    basename='condition-medication-schedule',
)
router.register(r'health-indicators', HealthIndicatorRecordViewSet, basename='health-indicator')

chronic_router.register(r'condition-types', ConditionTypeViewSet, basename='chronic-condition-type')
chronic_router.register(r'user-conditions', UserConditionViewSet, basename='chronic-user-condition')

urlpatterns = [
    path('admin/', admin.site.urls),

    # Auth
    path('api/auth/register/', RegisterView.as_view(), name='auth_register'),
    path('api/auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/auth/me/', ManageUserView.as_view(), name='user_manage'),

    # API
    path('api/', include(router.urls)),
    path('api/chronic/', include(chronic_router.urls)),
    path('api/health/constraints/recompute/', HealthConstraintRecomputeView.as_view(), name='health_constraints_recompute'),
    path('api/health/constraints/<str:tracker_type>/', HealthConstraintsView.as_view(), name='health_constraints_by_tracker'),
    path('api/health/constraints/', HealthConstraintsView.as_view(), name='health_constraints'),
    path('api/health/constraint-runs/', ConstraintResolutionRunListView.as_view(), name='health_constraint_runs'),
    path('api/health/', HealthCheckView.as_view(), name='health'),
    path('api/dashboard/', DashboardView.as_view(), name='dashboard'),
    path('api/history/', StatsHistoryView.as_view(), name='history'),
]
