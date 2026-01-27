from rest_framework import generics
from django.contrib.auth.models import User
from .serializers import RegisterSerializer
from users.services.user_profile_service import UserProfileService
from rest_framework.permissions import AllowAny

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = RegisterSerializer

# users/views.py
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .serializers import UserUpdateSerializer

class ManageUserView(generics.RetrieveUpdateDestroyAPIView):
    """
    واجهة تسمح للمستخدم بعرض وتعديل وحذف حسابه الشخصي
    FR-02 (حذف), FR-03 (تعديل), FR-24 (تحديث الوزن)
    """
    serializer_class = UserUpdateSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        # إجبار الواجهة على التعامل مع المستخدم الحالي فقط
        UserProfileService.ensure_profile(self.request.user)
        return self.request.user
