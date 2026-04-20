from rest_framework import serializers

from core.models import Habit, HabitLog, Medicine


class MedicineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medicine
        fields = "__all__"


class HabitSerializer(serializers.ModelSerializer):
    class Meta:
        model = Habit
        fields = "__all__"


class HabitLogSerializer(serializers.ModelSerializer):
    habit_name = serializers.CharField(source="habit.name", read_only=True)

    class Meta:
        model = HabitLog
        fields = ["id", "habit", "habit_name", "date", "completed"]
        read_only_fields = ["date"]
