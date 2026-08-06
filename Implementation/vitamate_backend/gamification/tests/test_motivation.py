from django.test import TestCase
from django.utils import timezone

from core.models import ActivityLog, IntegrationOutboxEvent
from core.services.orchestration.integration_outbox_service import (
    IntegrationOutboxService,
)
from gamification.models import (
    Badge,
    DailyMission,
    DailyMotivationState,
    MotivationExperienceEvent,
    PointsTransaction,
    UserBadge,
    UserStreak,
)
from gamification.services.motivation_feed_service import MotivationFeedService
from gamification.services.motivation_service import MotivationService
from test_utils.helpers import auth_client_for_user, create_exercise, create_food_item, create_user_with_profile


class MotivationServiceTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="motivation_user")
        self.client_auth = auth_client_for_user(self.user)

    def test_overview_envelope_and_daily_missions(self):
        payload = MotivationService.overview(user=self.user, request_id="test")
        self.assertIn("data", payload)
        self.assertIn("meta", payload)
        self.assertEqual(payload["meta"]["request_id"], "test")
        self.assertGreaterEqual(payload["data"]["missions_total"], 1)

    def test_refresh_daily_is_idempotent_for_missions(self):
        MotivationService.refresh_daily(user=self.user)
        MotivationService.refresh_daily(user=self.user)
        self.assertEqual(
            DailyMission.objects.filter(user=self.user).count(),
            len(MotivationService.DEFAULT_MISSIONS),
        )
        self.assertEqual(
            DailyMotivationState.objects.filter(user=self.user).count(),
            1,
        )

    def test_badges_are_seeded_and_exposed(self):
        payload = MotivationService.badges(user=self.user, request_id="test")
        self.assertIn("data", payload)
        self.assertIn("badges", payload["data"])
        self.assertEqual(Badge.objects.filter(is_active=True).count(), len(MotivationService.BADGE_DEFINITIONS))
        self.assertEqual(
            UserBadge.objects.filter(user=self.user).count(),
            len(MotivationService.BADGE_DEFINITIONS),
        )

    def test_medication_mission_is_not_applicable_without_medications(self):
        MotivationService.refresh_daily(user=self.user)
        mission = DailyMission.objects.get(user=self.user, mission_type="medications_all")
        self.assertEqual(mission.status, DailyMission.STATUS_NOT_APPLICABLE)
        self.assertFalse(UserStreak.objects.filter(user=self.user, streak_type="medications").exists())
        meds_badge = UserBadge.objects.select_related("badge").get(
            user=self.user,
            badge__code="meds_champion",
        )
        self.assertEqual(meds_badge.status, UserBadge.STATUS_IN_PROGRESS)
        self.assertEqual(meds_badge.progress_value, 0)

    def test_fast_food_mission_is_not_applicable_without_plan(self):
        MotivationService.refresh_daily(user=self.user)
        mission = DailyMission.objects.get(user=self.user, mission_type="avoid_fast_food")
        self.assertEqual(mission.status, DailyMission.STATUS_NOT_APPLICABLE)
        overview = MotivationService.overview(user=self.user, request_id="overview")
        self.assertEqual(
            overview["data"]["missions_total"],
            len(MotivationService.DEFAULT_MISSIONS) - 2,
        )

    def test_earned_badge_remains_earned_and_bonus_is_granted_once(self):
        exercise = create_exercise(name="Badge Run", met_value=8.0)
        for _ in range(5):
            ActivityLog.objects.create(user=self.user, exercise=exercise, duration_minutes=20)

        MotivationService.refresh_daily(user=self.user)
        badge = UserBadge.objects.select_related("badge").get(
            user=self.user,
            badge__code="active_starter",
        )
        self.assertEqual(badge.status, UserBadge.STATUS_EARNED)
        self.assertEqual(
            PointsTransaction.objects.filter(
                user=self.user,
                rule_code="BADGE_UNLOCKED",
                source_id="active_starter",
            ).count(),
            1,
        )
        self.assertTrue(
            MotivationExperienceEvent.objects.filter(
                user=self.user,
                event_type=MotivationExperienceEvent.TYPE_BADGE_EARNED,
                metadata__badge_code="active_starter",
            ).exists()
        )

    def test_meal_mission_completion_creates_experience_event(self):
        food = create_food_item(name="Mission Meal")
        for meal_type in ("breakfast", "lunch", "dinner"):
            response = self.client_auth.post(
                "/api/meals/",
                {
                    "food": food.id,
                    "meal_type": meal_type,
                    "quantity_grams": 100,
                },
                format="json",
            )
            self.assertEqual(response.status_code, 201)

        for event_id in IntegrationOutboxEvent.objects.filter(
            user=self.user,
            status=IntegrationOutboxEvent.STATUS_PENDING,
        ).values_list("id", flat=True):
            IntegrationOutboxService.process(event_id=event_id)

        mission = DailyMission.objects.get(
            user=self.user,
            mission_date=timezone.localdate(),
            mission_type="nutrition_meals",
        )
        self.assertEqual(mission.status, DailyMission.STATUS_COMPLETED)
        self.assertTrue(
            MotivationExperienceEvent.objects.filter(
                user=self.user,
                event_type=MotivationExperienceEvent.TYPE_MISSION_COMPLETED,
                metadata__mission_type="nutrition_meals",
            ).exists()
        )

    def test_feed_and_ack_flow(self):
        food = create_food_item(name="Feed Meal")
        response = self.client_auth.post(
            "/api/meals/",
            {
                "food": food.id,
                "meal_type": "breakfast",
                "quantity_grams": 120,
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201)

        payload = MotivationFeedService.feed(user=self.user, request_id="feed-test")
        data = payload["data"]
        self.assertIn("summary", data)
        self.assertIn("focus", data)
        self.assertIn("celebrations", data)
        self.assertGreaterEqual(len(data["celebrations"]), 1)

        celebration_id = data["celebrations"][0]["id"]
        ack = MotivationFeedService.acknowledge_celebrations(
            user=self.user,
            ids=[celebration_id],
            request_id="ack-test",
        )
        self.assertEqual(ack["data"]["acknowledged_ids"], [celebration_id])

        next_payload = MotivationFeedService.feed(user=self.user, request_id="feed-test-2")
        ids = [item["id"] for item in next_payload["data"]["celebrations"]]
        self.assertNotIn(celebration_id, ids)

    def test_get_endpoints_do_not_mutate_motivation_state(self):
        MotivationService.refresh_daily(user=self.user)
        mission = DailyMission.objects.filter(user=self.user).order_by("id").first()
        badge = UserBadge.objects.filter(user=self.user).order_by("id").first()
        state = DailyMotivationState.objects.get(user=self.user)
        before_counts = {
            "missions": DailyMission.objects.filter(user=self.user).count(),
            "streaks": UserStreak.objects.filter(user=self.user).count(),
            "badges": UserBadge.objects.filter(user=self.user).count(),
            "points": PointsTransaction.objects.filter(user=self.user).count(),
            "states": DailyMotivationState.objects.filter(user=self.user).count(),
        }
        mission_updated_at = mission.updated_at
        badge_updated_at = badge.updated_at
        state_generated_at = state.generated_at

        for endpoint in (
            "/api/motivation/overview/",
            "/api/motivation/missions/",
            "/api/motivation/badges/",
            "/api/home/overview/",
            "/api/progress/overview/",
        ):
            response = self.client_auth.get(endpoint)
            self.assertEqual(response.status_code, 200)

        mission.refresh_from_db()
        badge.refresh_from_db()
        state.refresh_from_db()
        after_counts = {
            "missions": DailyMission.objects.filter(user=self.user).count(),
            "streaks": UserStreak.objects.filter(user=self.user).count(),
            "badges": UserBadge.objects.filter(user=self.user).count(),
            "points": PointsTransaction.objects.filter(user=self.user).count(),
            "states": DailyMotivationState.objects.filter(user=self.user).count(),
        }

        self.assertEqual(before_counts, after_counts)
        self.assertEqual(mission.updated_at, mission_updated_at)
        self.assertEqual(badge.updated_at, badge_updated_at)
        self.assertEqual(state.generated_at, state_generated_at)
