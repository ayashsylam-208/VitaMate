from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from users.services.user_profile_service import UserProfileService
from gamification.repositories.user_score_repository import UserScoreRepository


@receiver(post_save, sender=User)
def create_user_related_records(sender, instance, created, **kwargs):
    UserProfileService.ensure_profile(instance)
    UserScoreRepository.get_or_create_for_user(instance)


@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    UserProfileService.ensure_profile(instance)
