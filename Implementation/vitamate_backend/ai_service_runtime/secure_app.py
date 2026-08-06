from __future__ import annotations

import asyncio
import datetime as datetime_module
import hmac
import os

from fastapi import Request
from fastapi.responses import JSONResponse

# The packaged runtime uses datetime.UTC, which was added in Python 3.11.
if not hasattr(datetime_module, "UTC"):
    datetime_module.UTC = datetime_module.timezone.utc

from vitamate_ai_package.api.app import create_app
from vitamate_ai_package.pipeline.service import get_pipeline


def _positive_int(name: str, default: int) -> int:
    try:
        return max(int(os.getenv(name, str(default))), 1)
    except ValueError as exc:
        raise RuntimeError(f"{name} must be a positive integer.") from exc


SERVICE_TOKEN = os.getenv("AI_MEALS_SERVICE_TOKEN", "").strip()
ALLOW_INSECURE = os.getenv("AI_RUNTIME_ALLOW_INSECURE", "0") == "1"
if len(SERVICE_TOKEN) < 32 and not ALLOW_INSECURE:
    raise RuntimeError(
        "AI_MEALS_SERVICE_TOKEN must contain at least 32 characters. "
        "Set AI_RUNTIME_ALLOW_INSECURE=1 only for isolated local diagnostics."
    )

MAX_CONCURRENCY = _positive_int("AI_RUNTIME_MAX_CONCURRENCY", 1)
MAX_QUEUE_SIZE = _positive_int("AI_RUNTIME_MAX_QUEUE_SIZE", 2)
QUEUE_TIMEOUT_SECONDS = _positive_int("AI_RUNTIME_QUEUE_TIMEOUT_SECONDS", 20)
MAX_IMAGE_BYTES = _positive_int("AI_MEALS_MAX_IMAGE_BYTES", 10 * 1024 * 1024)

app = create_app()
app.state.analysis_semaphore = asyncio.Semaphore(MAX_CONCURRENCY)
app.state.analysis_queue_lock = asyncio.Lock()
app.state.analysis_waiters = 0
app.state.readiness_lock = asyncio.Lock()

@app.middleware("http")
async def protect_runtime(request: Request, call_next):
    protected = request.url.path in {"/analyze", "/finalize"}
    if protected and not ALLOW_INSECURE:
        supplied = request.headers.get("X-VitaMate-Service-Token", "")
        if not hmac.compare_digest(supplied, SERVICE_TOKEN):
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid service credentials."},
            )

    if request.url.path != "/analyze":
        return await call_next(request)

    content_length = request.headers.get("content-length")
    if content_length:
        try:
            request_bytes = int(content_length)
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Invalid Content-Length."})
        # Multipart framing adds a small overhead around the image itself.
        if request_bytes > MAX_IMAGE_BYTES + 256 * 1024:
            return JSONResponse(status_code=413, content={"detail": "Meal image is too large."})

    async with app.state.analysis_queue_lock:
        if app.state.analysis_waiters >= MAX_QUEUE_SIZE:
            return JSONResponse(
                status_code=429,
                content={"detail": "The analysis queue is full. Retry shortly."},
                headers={"Retry-After": "10"},
            )
        app.state.analysis_waiters += 1

    acquired = False
    try:
        await asyncio.wait_for(
            app.state.analysis_semaphore.acquire(),
            timeout=QUEUE_TIMEOUT_SECONDS,
        )
        acquired = True
    except asyncio.TimeoutError:
        return JSONResponse(
            status_code=503,
            content={"detail": "The analysis queue timed out."},
            headers={"Retry-After": "10"},
        )
    finally:
        async with app.state.analysis_queue_lock:
            app.state.analysis_waiters -= 1

    try:
        return await call_next(request)
    finally:
        if acquired:
            app.state.analysis_semaphore.release()


@app.get("/readyz")
async def readyz():
    prewarm = getattr(app.state, "pipeline_prewarm_status", {"status": "unknown"})
    if prewarm.get("status") != "ready":
        async with app.state.readiness_lock:
            prewarm = getattr(
                app.state,
                "pipeline_prewarm_status",
                {"status": "unknown"},
            )
            if prewarm.get("status") != "ready":
                try:
                    details = await asyncio.to_thread(
                        get_pipeline().prewarm,
                        load_semantic_models=True,
                    )
                    prewarm = {"enabled": True, "status": "ready", **details}
                except Exception as exc:  # pragma: no cover - vendor/GPU dependent
                    prewarm = {
                        "enabled": True,
                        "status": "failed",
                        "error": str(exc),
                    }
                app.state.pipeline_prewarm_status = prewarm
    if prewarm.get("status") != "ready":
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "pipeline": prewarm},
        )
    return {
        "status": "ready",
        "pipeline": prewarm,
        "max_concurrency": MAX_CONCURRENCY,
        "max_queue_size": MAX_QUEUE_SIZE,
    }
