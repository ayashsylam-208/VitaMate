from __future__ import annotations

import csv
import io
import json

from django.contrib.auth import get_user_model
from django.core.management.base import CommandError


def add_output_arguments(parser):
    parser.add_argument("--format", choices=("json", "csv"), default="json")
    parser.add_argument("--dry-run", action="store_true", default=False)
    parser.add_argument("--batch-size", type=int, default=200)
    parser.add_argument("--strict", action="store_true", default=False)


def add_user_arguments(parser):
    parser.add_argument("--user-id", type=int)
    parser.add_argument("--all", action="store_true", dest="all_users")


def selected_users(options):
    queryset = get_user_model().objects.order_by("id")
    if options.get("user_id"):
        queryset = queryset.filter(pk=options["user_id"])
    elif not options.get("all_users"):
        raise CommandError("Provide --user-id or --all.")
    return queryset.iterator(chunk_size=max(int(options.get("batch_size") or 200), 1))


def render_rows(rows: list[dict], output_format: str) -> str:
    if output_format == "json":
        return json.dumps(rows, indent=2, default=str, sort_keys=True)
    if not rows:
        return ""
    fieldnames = sorted({key for row in rows for key in row})
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
    return buffer.getvalue().rstrip()


def fail_if_strict(*, strict: bool, issues: int):
    if strict and issues:
        raise CommandError(f"Audit found {issues} issue(s).")
