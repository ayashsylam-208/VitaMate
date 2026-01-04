# Register your models here.
from django.contrib import admin
from .models import UserProfile

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'gender', 'current_weight', 'daily_calorie_target', 'daily_water_target')
    search_fields = ('user__username', 'user__email')
    
    def current_weight(self, obj):
        return f"{obj.weight} kg"