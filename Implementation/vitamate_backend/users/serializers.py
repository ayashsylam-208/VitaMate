from rest_framework import serializers
from django.contrib.auth.models import User
from users.services.user_profile_service import UserProfileService

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
        profile_data = validated_data.pop('userprofile', {})
        return UserProfileService.update_user_and_profile(
            user=instance,
            user_data=validated_data,
            profile_data=profile_data,
        )
