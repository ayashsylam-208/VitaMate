from django.contrib import admin
from .models import UserScore

@admin.register(UserScore)
class UserScoreAdmin(admin.ModelAdmin):
    list_display = ('user', 'total_points', 'level')
    ordering = ('-total_points',) # ترتيب تنازلي حسب النقاط (لمعرفة المتصدرين)