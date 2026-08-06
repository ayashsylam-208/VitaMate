import json
from io import StringIO

from django.core.management import call_command
from django.test import TestCase

from test_utils.helpers import create_user_with_profile


class HealthMaintenanceCommandTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="health-command-user")

    def test_stale_state_report_uses_real_source_timestamps(self):
        output = StringIO()
        call_command(
            "report_stale_health_states",
            user_id=self.user.id,
            format="json",
            stdout=output,
        )
        rows = json.loads(output.getvalue())
        self.assertEqual(rows[0]["user_id"], self.user.id)
        self.assertTrue(rows[0]["stale"])

    def test_recovery_commands_support_safe_dry_run(self):
        for command_name in ("rebuild_user_constraints", "rebuild_unified_health_state"):
            output = StringIO()
            call_command(
                command_name,
                user_id=self.user.id,
                dry_run=True,
                format="json",
                stdout=output,
            )
            rows = json.loads(output.getvalue())
            self.assertEqual(rows[0]["status"], "dry_run")
