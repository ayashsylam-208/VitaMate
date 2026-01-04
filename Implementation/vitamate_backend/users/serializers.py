from rest_framework import serializers
from django.contrib.auth.models import User
from .models import UserProfile

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('username', 'password', 'email', 'first_name', 'last_name')

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            password=validated_data['password'],
            email=validated_data.get('email', ''),
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', '')
        )
        return user
# users/serializers.py

class UserUpdateSerializer(serializers.ModelSerializer):
    # حقول من UserProfile لتعديلها مباشرة
    weight = serializers.FloatField(source='userprofile.weight')
    height = serializers.FloatField(source='userprofile.height')
    activity_level = serializers.FloatField(source='userprofile.activity_level')
    goal = serializers.CharField(source='userprofile.goal')
    daily_step_goal = serializers.IntegerField(source='userprofile.daily_step_goal')
    gender = serializers.CharField(source='userprofile.gender', read_only=True) # الجنس عادة لا يتغير بسهولة طبياً

    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email', 'weight', 'height', 'activity_level', 'goal', 'daily_step_goal', 'gender']

    def update(self, instance, validated_data):
        # 1. تحديث بيانات المستخدم الأساسية (User)
        profile_data = validated_data.pop('userprofile', {})
        
        instance.first_name = validated_data.get('first_name', instance.first_name)
        instance.last_name = validated_data.get('last_name', instance.last_name)
        instance.email = validated_data.get('email', instance.email)
        instance.save()

        # 2. تحديث بيانات الملف الشخصي (UserProfile)
        profile = instance.userprofile
        profile.weight = profile_data.get('weight', profile.weight)
        profile.height = profile_data.get('height', profile.height)
        profile.activity_level = profile_data.get('activity_level', profile.activity_level)
        profile.goal = profile_data.get('goal', profile.goal)
        profile.daily_step_goal = profile_data.get('daily_step_goal', profile.daily_step_goal)
        
        # إعادة حساب المعدلات الحيوية بعد التعديل (FR-24)
        profile.calculate_metrics()
        profile.save()

        return instance