from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from core.views import (
    MealLogViewSet, WaterLogViewSet, MedicineViewSet, 
    StepLogViewSet, ActivityLogViewSet, SleepLogViewSet, 
    HabitViewSet, DashboardView
)
from users.views import RegisterView , ManageUserView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

# إعداد الراوتر لجميع الواجهات
router = DefaultRouter()
router.register(r'meals', MealLogViewSet, basename='meal')
router.register(r'water', WaterLogViewSet, basename='water')
router.register(r'medicines', MedicineViewSet, basename='medicine')
router.register(r'steps', StepLogViewSet, basename='steps')
router.register(r'activities', ActivityLogViewSet, basename='activity')
router.register(r'sleep', SleepLogViewSet, basename='sleep')
router.register(r'habits', HabitViewSet, basename='habit')

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # المصادقة (Auth)
    path('api/auth/register/', RegisterView.as_view(), name='auth_register'), # الرابط الجديد
    path('api/auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/auth/me/', ManageUserView.as_view(), name='user_manage'), # الرابط الجديد للتعديل والحذف

    # الميزات الأساسية
    path('api/', include(router.urls)),
    path('api/dashboard/', DashboardView.as_view(), name='dashboard'),
]