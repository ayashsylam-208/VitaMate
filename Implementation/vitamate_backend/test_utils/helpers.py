from datetime import date

from django.contrib.auth.models import User
from rest_framework.test import APIClient

from core.models import FoodItem, Exercise, StepLog
from users.models import UserProfile
from users.services.user_profile_service import UserProfileService


def create_user_with_profile(
    username: str,
    password: str = "Pass123!",
    email: str | None = None,
    *,
    height: float = 170,
    weight: float = 70,
    gender: str = "M",
    activity_level: float = 1.2,
) -> User:
    """
    Factory: create a user and attach/update UserProfile with sensible defaults.
    Handles cases where signals already created a profile.
    """
    user, _ = User.objects.get_or_create(
        username=username,
        defaults={
            "password": password,
            "email": email or f"{username}@example.com",
            "first_name": "Test",
            "last_name": "User",
        },
    )
    if not user.check_password(password):
        user.set_password(password)
        user.save()

    profile, _ = UserProfile.objects.get_or_create(
        user=user,
        defaults={
            "birth_date": date(2000, 1, 1),
            "gender": gender,
            "height": height,
            "weight": weight,
            "activity_level": activity_level,
        },
    )
    profile.gender = gender
    profile.height = height
    profile.weight = weight
    profile.activity_level = activity_level
    UserProfileService.recalculate_profile(profile)
    return user


def auth_client_for_user(user: User, password: str = "Pass123!") -> APIClient:
    """
    Login through SimpleJWT and return an APIClient with Authorization header set.
    """
    client = APIClient()
    res = client.post(
        "/api/auth/login/",
        {"username": user.username, "password": password},
        format="json",
    )
    assert res.status_code == 200, f"Login failed for user {user.username}: {res.content}"
    token = res.data["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return client


def create_food_item(**kwargs) -> FoodItem:
    defaults = {
        "name": "Test Food",
        "calories_100g": 200,
        "protein_100g": 10,
        "carbs_100g": 20,
        "fat_100g": 5,
    }
    defaults.update(kwargs)
    return FoodItem.objects.create(**defaults)


def create_exercise(**kwargs) -> Exercise:
    defaults = {"name": "Run", "met_value": 8.0}
    defaults.update(kwargs)
    return Exercise.objects.create(**defaults)


def get_steps_for(user: User, log_date: date | None = None) -> StepLog | None:
    return StepLog.objects.filter(user=user, date=log_date or date.today()).first()
