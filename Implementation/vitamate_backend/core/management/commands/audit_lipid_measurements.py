from django.core.management.base import BaseCommand

from core.management.commands._health_command_utils import (
    add_output_arguments,
    fail_if_strict,
    render_rows,
)
from core.models import HealthIndicatorRecord
from core.services.chronic.lipid_panel_values import LipidPanelValues


class Command(BaseCommand):
    help = "Audit lipid records without changing canonical generic fields."

    def add_arguments(self, parser):
        add_output_arguments(parser)
        parser.add_argument("--user-id", type=int)
        parser.add_argument("--repair-payload", action="store_true", default=False)

    def handle(self, *args, **options):
        queryset = HealthIndicatorRecord.objects.filter(indicator_type="lipid_panel").select_related(
            "user_condition"
        ).order_by("id")
        if options.get("user_id"):
            queryset = queryset.filter(user_condition__user_id=options["user_id"])
        rows = []
        repaired = 0
        for record in queryset.iterator(chunk_size=max(options["batch_size"], 1)):
            values = LipidPanelValues.from_measurement(record)
            payload = dict(record.payload or {})
            issues = []
            if not any(
                value is not None
                for value in (
                    values.ldl_mg_dl,
                    values.hdl_mg_dl,
                    values.triglycerides_mg_dl,
                )
            ):
                issues.append("no_lipid_values")
            if str(record.unit or "").lower().replace(" ", "") not in {"mg/dl", "mgdl"}:
                issues.append("unexpected_unit")
            for payload_key, field_value in (
                ("ldl", record.value_1),
                ("hdl", record.value_2),
                ("triglycerides", record.value_3),
            ):
                payload_value = LipidPanelValues._number(payload.get(payload_key))
                if payload_value is not None and field_value is not None and float(payload_value) != float(field_value):
                    issues.append(f"payload_{payload_key}_conflict")
            if options["repair_payload"] and not options["dry_run"] and not any(
                item.endswith("_conflict") for item in issues
            ):
                record.payload = {
                    **payload,
                    "ldl": values.ldl_mg_dl,
                    "hdl": values.hdl_mg_dl,
                    "triglycerides": values.triglycerides_mg_dl,
                }
                record.save(update_fields=["payload"])
                repaired += 1
            rows.append(
                {
                    "record_id": record.id,
                    "user_id": record.user_condition.user_id,
                    "ldl": values.ldl_mg_dl,
                    "hdl": values.hdl_mg_dl,
                    "triglycerides": values.triglycerides_mg_dl,
                    "issues": ",".join(issues),
                    "repaired": bool(options["repair_payload"] and not options["dry_run"] and not issues),
                }
            )
        self.stdout.write(render_rows(rows, options["format"]))
        self.stderr.write(f"audited={len(rows)} repaired={repaired} dry_run={options['dry_run']}")
        fail_if_strict(strict=options["strict"], issues=sum(bool(row["issues"]) for row in rows))
