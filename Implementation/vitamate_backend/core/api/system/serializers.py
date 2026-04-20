from rest_framework import serializers

from users.models import UserProfile


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ["id", "user", "height", "weight", "age", "gender", "activity_level", "dietary_goal"]
        read_only_fields = ["user"]


class DailyReportSerializer(serializers.Serializer):
    date = serializers.DateField(read_only=True)
    total_calories_consumed = serializers.IntegerField(read_only=True)
    total_calories_burned = serializers.IntegerField(read_only=True)
    total_water_intake = serializers.IntegerField(read_only=True)
    total_steps = serializers.IntegerField(read_only=True)
    sleep_duration_hours = serializers.FloatField(read_only=True)
    points_earned = serializers.IntegerField(read_only=True)

    class Meta:
        read_only = True
