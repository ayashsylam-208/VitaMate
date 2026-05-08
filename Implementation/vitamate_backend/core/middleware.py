from __future__ import annotations

import json
import logging
import time
import uuid

from django.conf import settings
from django.db import connections


logger = logging.getLogger("vitamate.performance")


class PerformanceInstrumentationMiddleware:
    """
    Lightweight request instrumentation for development and test runs.

    The middleware records request timing, response size, query count, and any
    view-level serializer timing marks exposed via ``request._perf_*`` fields.
    """

    DEBUG_PATH_PREFIXES = (
        "/api/home/",
        "/api/progress/",
        "/api/nutrition/summary/",
        "/api/hydration/summary/",
        "/api/sleep/summary/",
        "/api/steps/summary/",
        "/api/activity/summary/",
        "/api/medications/overview/",
        "/api/chronic/overview/",
    )

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request_id = uuid.uuid4().hex
        request.request_id = request_id
        request._perf_serializer_ms = 0.0
        request._perf_query_budget = None

        debug_enabled = getattr(settings, "PERFORMANCE_INSTRUMENTATION_ENABLED", settings.DEBUG)
        query_counts_before = {}
        original_debug_flags = {}
        if debug_enabled:
            for connection in connections.all():
                alias = connection.alias
                original_debug_flags[alias] = connection.force_debug_cursor
                connection.force_debug_cursor = True
                query_counts_before[alias] = len(connection.queries)

        started = time.perf_counter()
        response = self.get_response(request)
        request_duration_ms = round((time.perf_counter() - started) * 1000, 2)

        query_count = 0
        if debug_enabled:
            for connection in connections.all():
                alias = connection.alias
                query_count += max(len(connection.queries) - query_counts_before.get(alias, 0), 0)
                connection.force_debug_cursor = original_debug_flags.get(alias, False)

        response_size = self._response_size(response)
        serializer_ms = round(float(getattr(request, "_perf_serializer_ms", 0.0) or 0.0), 2)
        recompute_ms = round(float(getattr(request, "_perf_recompute_ms", 0.0) or 0.0), 2)

        if self._should_attach_headers(request.path):
            response["X-VitaMate-Request-Id"] = request_id
            response["X-VitaMate-Latency-Ms"] = str(request_duration_ms)
            response["X-VitaMate-Db-Queries"] = str(query_count)
            response["X-VitaMate-Serializer-Ms"] = str(serializer_ms)
            response["X-VitaMate-Response-Bytes"] = str(response_size)
            response["X-VitaMate-Recompute-Ms"] = str(recompute_ms)

        if debug_enabled:
            logger.info(
                json.dumps(
                    {
                        "event": "http_request_metrics",
                        "request_id": request_id,
                        "method": request.method,
                        "path": request.path,
                        "status_code": getattr(response, "status_code", 0),
                        "latency_ms": request_duration_ms,
                        "response_bytes": response_size,
                        "db_query_count": query_count,
                        "serializer_ms": serializer_ms,
                        "recompute_ms": recompute_ms,
                    }
                )
            )

        return response

    @classmethod
    def _should_attach_headers(cls, path: str) -> bool:
        return any(path.startswith(prefix) for prefix in cls.DEBUG_PATH_PREFIXES)

    @staticmethod
    def _response_size(response) -> int:
        if getattr(response, "streaming", False):
            return 0
        try:
            if hasattr(response, "render") and callable(response.render):
                response.render()
            content = getattr(response, "content", b"") or b""
            return len(content)
        except Exception:
            return 0
