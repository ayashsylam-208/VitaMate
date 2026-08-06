from __future__ import annotations

from datetime import date

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from gamification.services.reconciliation_service import ReconciliationService


class Command(BaseCommand):
    help = "Reconcile gamification points for a user on a day or a date range."

    def add_arguments(self, parser):
        parser.add_argument("--user", type=int, required=True, help="User id to reconcile.")
        parser.add_argument("--date", type=str, help="Single date in YYYY-MM-DD format.")
        parser.add_argument("--start-date", type=str, help="Range start date in YYYY-MM-DD format.")
        parser.add_argument("--end-date", type=str, help="Range end date in YYYY-MM-DD format.")

    @staticmethod
    def _parse_date(value: str | None, *, option: str) -> date | None:
        if not value:
            return None
        try:
            return date.fromisoformat(value)
        except ValueError as exc:
            raise CommandError(f"{option} must be in YYYY-MM-DD format.") from exc

    def handle(self, *args, **options):
        user_id = options["user"]
        target_date = self._parse_date(options.get("date"), option="--date")
        start_date = self._parse_date(options.get("start_date"), option="--start-date")
        end_date = self._parse_date(options.get("end_date"), option="--end-date")
        if target_date is None and start_date is None and end_date is None:
            raise CommandError("Provide --date or both --start-date and --end-date.")
        if target_date is not None and (start_date is not None or end_date is not None):
            raise CommandError("Use either --date or the range options, not both.")
        if (start_date is None) != (end_date is None):
            raise CommandError("Provide both --start-date and --end-date for range mode.")

        User = get_user_model()
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist as exc:
            raise CommandError(f"User {user_id} does not exist.") from exc

        if target_date is not None:
            result = ReconciliationService.reconcile_user_day(
                user=user,
                target_date=target_date,
            )
            self.stdout.write(
                self.style.SUCCESS(
                    f"Reconciled user={user.id} date={result['date']} "
                    f"created={result['transactions_created']} total_points={result['total_points']}"
                )
            )
            return

        results = ReconciliationService.reconcile_user_range(
            user=user,
            start_date=start_date,
            end_date=end_date,
        )
        created = sum(int(item.get("transactions_created") or 0) for item in results)
        self.stdout.write(
            self.style.SUCCESS(
                f"Reconciled user={user.id} range={start_date.isoformat()}..{end_date.isoformat()} "
                f"days={len(results)} created={created}"
            )
        )
