from datetime import date
from unittest.mock import patch

from django.test import TestCase

from core.models import IntegrationOutboxEvent
from core.services.orchestration.integration_outbox_service import (
    IntegrationOutboxService,
)
from test_utils.helpers import create_user_with_profile


class IntegrationOutboxServiceTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="outbox-user")
        self.target_date = date(2026, 8, 3)

    @patch("core.tasks.dispatch_integration_outbox_event")
    def test_enqueue_is_deduplicated_and_dispatches_after_commit(self, dispatch):
        with self.captureOnCommitCallbacks(execute=True):
            first = IntegrationOutboxService.enqueue_motivation_refresh(
                user=self.user,
                target_date=self.target_date,
                source_ref="meal:44",
            )
            second = IntegrationOutboxService.enqueue_motivation_refresh(
                user=self.user,
                target_date=self.target_date,
                source_ref="meal:44",
            )

        self.assertEqual(first.id, second.id)
        self.assertEqual(IntegrationOutboxEvent.objects.count(), 1)
        dispatch.assert_called_once_with(event_id=first.id)

    @patch("gamification.services.motivation_service.MotivationService.refresh_daily")
    def test_processed_event_is_not_executed_twice(self, refresh_daily):
        event = IntegrationOutboxEvent.objects.create(
            user=self.user,
            event_type=IntegrationOutboxService.EVENT_MOTIVATION_REFRESH,
            dedupe_key="motivation:processed-once",
            payload={"target_date": self.target_date.isoformat()},
        )

        IntegrationOutboxService.process(event_id=event.id)
        IntegrationOutboxService.process(event_id=event.id)

        event.refresh_from_db()
        self.assertEqual(event.status, IntegrationOutboxEvent.STATUS_PROCESSED)
        self.assertEqual(event.attempts, 1)
        refresh_daily.assert_called_once_with(
            user=self.user,
            target_date=self.target_date,
        )

    @patch("gamification.services.motivation_service.MotivationService.refresh_daily")
    def test_failed_event_can_be_retried(self, refresh_daily):
        refresh_daily.side_effect = [RuntimeError("temporary"), None]
        event = IntegrationOutboxEvent.objects.create(
            user=self.user,
            event_type=IntegrationOutboxService.EVENT_MOTIVATION_REFRESH,
            dedupe_key="motivation:retry",
            payload={"target_date": self.target_date.isoformat()},
        )

        with self.assertRaises(RuntimeError):
            IntegrationOutboxService.process(event_id=event.id)
        IntegrationOutboxService.process(event_id=event.id)

        event.refresh_from_db()
        self.assertEqual(event.status, IntegrationOutboxEvent.STATUS_PROCESSED)
        self.assertEqual(event.attempts, 2)

    @patch("gamification.services.motivation_service.MotivationService.refresh_daily")
    def test_processing_event_is_not_claimed_again(self, refresh_daily):
        event = IntegrationOutboxEvent.objects.create(
            user=self.user,
            event_type=IntegrationOutboxService.EVENT_MOTIVATION_REFRESH,
            dedupe_key="motivation:already-processing",
            payload={"target_date": self.target_date.isoformat()},
            status=IntegrationOutboxEvent.STATUS_PROCESSING,
        )

        IntegrationOutboxService.process(event_id=event.id)

        refresh_daily.assert_not_called()
        event.refresh_from_db()
        self.assertEqual(event.attempts, 0)
