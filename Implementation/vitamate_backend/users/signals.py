from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import UserProfile
from gamification.models import UserScore

@receiver(post_save, sender=User)
def create_user_related_records(sender, instance, created, **kwargs):
    if created:
        # 1. إنشاء ملف شخصي بقيم افتراضية
        UserProfile.objects.create(
            user=instance,
            birth_date='2000-01-01', # تاريخ افتراضي يعدله المستخدم لاحقاً
            gender='M',
            height=170,
            weight=70
        )
        # 2. إنشاء رصيد نقاط (Gamification)
        UserScore.objects.create(user=instance)

@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs): 
    instance.userprofile.save()