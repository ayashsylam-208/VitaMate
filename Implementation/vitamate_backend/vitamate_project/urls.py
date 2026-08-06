from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from core.views import (
    MealLogViewSet, WaterLogViewSet, HydrationLogViewSet, MedicineViewSet,
    StepLogViewSet, ActivityLogViewSet, SleepLogViewSet,
    SleepCoachCancelPlanView, SleepCoachFeedbackView, SleepCoachPlanView,
    SleepCoachTodayView, ActivityActiveSessionView, ActivitySessionCancelView,
    ActivitySessionCreateView, ActivitySessionEditView, ActivitySessionFinishView,
    ActivitySessionPauseView, ActivitySessionResumeView,
    UnhealthyHabitAtomicSetupView, UnhealthyHabitBaselineView,
    UnhealthyHabitCreateView, UnhealthyHabitDailyCheckInView,
    UnhealthyHabitLogDetailView, UnhealthyHabitLogView,
    UnhealthyHabitOverviewView, UnhealthyHabitPauseView, UnhealthyHabitPlanView,
    UnhealthyHabitReminderView, UnhealthyHabitResumeView,
    HabitViewSet, FoodItemViewSet, ExerciseViewSet,
    DashboardView, HealthCheckView, NutritionFactsViewSet,
    NutritionServingOptionViewSet, StatsHistoryView,
    HomeOverviewView, ProgressOverviewView, ProgressHistoryView,
    ProgressDetailView,
    NutritionSummaryView, HydrationSummaryView, SleepSummaryView,
    StepsSummaryView, ActivitySummaryView, MedicationsOverviewView,
    ChronicOverviewView, OpenApiSchemaView, MicronutrientOverviewView,
    MicronutrientTargetView, MotivationOverviewView, MotivationPointsView,
    MotivationMissionsView, MotivationMissionRefreshView, MotivationBadgesView,
    MotivationFeedView, MotivationCelebrationsAckView,
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
router.register(r'hydration/logs', HydrationLogViewSet, basename='hydration-log')
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

    path('api/schema/', OpenApiSchemaView.as_view(), name='openapi-schema'),
    path('api/home/overview/', HomeOverviewView.as_view(), name='home-overview'),
    path('api/progress/overview/', ProgressOverviewView.as_view(), name='progress-overview'),
    path('api/progress/history/', ProgressHistoryView.as_view(), name='progress-history'),
    path('api/progress/details/<str:tracker>/', ProgressDetailView.as_view(), name='progress-detail'),
    path('api/nutrition/summary/', NutritionSummaryView.as_view(), name='nutrition-summary'),
    path('api/nutrition/micronutrients/', MicronutrientOverviewView.as_view(), name='nutrition-micronutrients'),
    path('api/nutrition/micronutrients/targets/', MicronutrientTargetView.as_view(), name='nutrition-micronutrient-targets'),
    path('api/hydration/summary/', HydrationSummaryView.as_view(), name='hydration-summary'),
    path('api/sleep/summary/', SleepSummaryView.as_view(), name='sleep-summary'),
    path('api/sleep/coach/today/', SleepCoachTodayView.as_view(), name='sleep-coach-today'),
    path('api/sleep/coach/plans/', SleepCoachPlanView.as_view(), name='sleep-coach-plans'),
    path('api/sleep/coach/plans/cancel/', SleepCoachCancelPlanView.as_view(), name='sleep-coach-plan-cancel'),
    path('api/sleep/coach/feedback/', SleepCoachFeedbackView.as_view(), name='sleep-coach-feedback'),
    path('api/steps/summary/', StepsSummaryView.as_view(), name='steps-summary'),
    path('api/activity/summary/', ActivitySummaryView.as_view(), name='activity-summary'),
    path('api/activity/sessions/active/', ActivityActiveSessionView.as_view(), name='activity-session-active'),
    path('api/activity/sessions/', ActivitySessionCreateView.as_view(), name='activity-session-create'),
    path('api/activity/sessions/<int:session_id>/pause/', ActivitySessionPauseView.as_view(), name='activity-session-pause'),
    path('api/activity/sessions/<int:session_id>/resume/', ActivitySessionResumeView.as_view(), name='activity-session-resume'),
    path('api/activity/sessions/<int:session_id>/edit/', ActivitySessionEditView.as_view(), name='activity-session-edit'),
    path('api/activity/sessions/<int:session_id>/finish/', ActivitySessionFinishView.as_view(), name='activity-session-finish'),
    path('api/activity/sessions/<int:session_id>/cancel/', ActivitySessionCancelView.as_view(), name='activity-session-cancel'),
    path('api/medications/overview/', MedicationsOverviewView.as_view(), name='medications-overview'),
    path('api/chronic/overview/', ChronicOverviewView.as_view(), name='chronic-overview'),
    path('api/motivation/overview/', MotivationOverviewView.as_view(), name='motivation-overview'),
    path('api/motivation/points/', MotivationPointsView.as_view(), name='motivation-points'),
    path('api/motivation/missions/', MotivationMissionsView.as_view(), name='motivation-missions'),
    path('api/motivation/missions/<int:mission_id>/refresh/', MotivationMissionRefreshView.as_view(), name='motivation-mission-refresh'),
    path('api/motivation/badges/', MotivationBadgesView.as_view(), name='motivation-badges'),
    path('api/motivation/feed/', MotivationFeedView.as_view(), name='motivation-feed'),
    path('api/motivation/celebrations/ack/', MotivationCelebrationsAckView.as_view(), name='motivation-celebrations-ack'),
    path('api/notification-hub/', include('notification_hub.urls')),
    path('api/manager/', include('manager.urls')),
    path('api/nutrition/ai-meals/', include('ai_meals.urls')),
    path('api/habits/unhealthy/overview/', UnhealthyHabitOverviewView.as_view(), name='unhealthy-habits-overview'),
    path('api/habits/unhealthy/setup/', UnhealthyHabitAtomicSetupView.as_view(), name='unhealthy-habits-setup'),
    path('api/habits/unhealthy/', UnhealthyHabitCreateView.as_view(), name='unhealthy-habits-create'),
    path('api/habits/unhealthy/<int:habit_id>/baseline/', UnhealthyHabitBaselineView.as_view(), name='unhealthy-habits-baseline'),
    path('api/habits/unhealthy/<int:habit_id>/plan/', UnhealthyHabitPlanView.as_view(), name='unhealthy-habits-plan'),
    path('api/habits/unhealthy/<int:habit_id>/logs/', UnhealthyHabitLogView.as_view(), name='unhealthy-habits-logs'),
    path('api/habits/unhealthy/<int:habit_id>/logs/<int:log_id>/', UnhealthyHabitLogDetailView.as_view(), name='unhealthy-habits-log-detail'),
    path('api/habits/unhealthy/<int:habit_id>/daily-check-in/', UnhealthyHabitDailyCheckInView.as_view(), name='unhealthy-habits-daily-check-in'),
    path('api/habits/unhealthy/<int:habit_id>/reminders/', UnhealthyHabitReminderView.as_view(), name='unhealthy-habits-reminders'),
    path('api/habits/unhealthy/<int:habit_id>/pause/', UnhealthyHabitPauseView.as_view(), name='unhealthy-habits-pause'),
    path('api/habits/unhealthy/<int:habit_id>/resume/', UnhealthyHabitResumeView.as_view(), name='unhealthy-habits-resume'),

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

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
