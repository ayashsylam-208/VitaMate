from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from core.views import (
    MealLogViewSet, WaterLogViewSet, MedicineViewSet,
    StepLogViewSet, ActivityLogViewSet, SleepLogViewSet,
    HabitViewSet, FoodItemViewSet, ExerciseViewSet,
    DashboardView, StatsHistoryView,
)
from users.views import RegisterView, ManageUserView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

# Routers
router = DefaultRouter()
router.register(r'meals', MealLogViewSet, basename='meal')
router.register(r'foods', FoodItemViewSet, basename='food')
router.register(r'water', WaterLogViewSet, basename='water')
router.register(r'medicines', MedicineViewSet, basename='medicine')
router.register(r'steps', StepLogViewSet, basename='steps')
router.register(r'activities', ActivityLogViewSet, basename='activity')
router.register(r'sleep', SleepLogViewSet, basename='sleep')
router.register(r'habits', HabitViewSet, basename='habit')
router.register(r'exercises', ExerciseViewSet, basename='exercise')

urlpatterns = [
    path('admin/', admin.site.urls),

    # Auth
    path('api/auth/register/', RegisterView.as_view(), name='auth_register'),
    path('api/auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/auth/me/', ManageUserView.as_view(), name='user_manage'),

    # API
    path('api/', include(router.urls)),
    path('api/dashboard/', DashboardView.as_view(), name='dashboard'),
    path('api/history/', StatsHistoryView.as_view(), name='history'),
]
