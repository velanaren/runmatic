import time
from collections.abc import Callable

from prometheus_client import Counter, Gauge, Histogram, generate_latest
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

REQUEST_DURATION = Histogram(
    "api_request_duration_seconds",
    "HTTP request duration in seconds",
    labelnames=["method", "endpoint", "status_code"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)

REQUEST_COUNT = Counter(
    "api_requests_total",
    "Total HTTP requests",
    labelnames=["method", "endpoint", "status_code"],
)

RUNBOOK_COUNT = Gauge(
    "runbook_total",
    "Total number of runbooks by status",
    labelnames=["status"],
)


def metrics_response() -> Response:
    return Response(
        content=generate_latest(),
        media_type="text/plain; version=0.0.4; charset=utf-8",
    )


class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()

        # Normalize path to avoid high cardinality (e.g. /runbooks/123 → /runbooks/{id})
        path = request.url.path
        for segment in path.split("/"):
            if segment.isdigit():
                path = path.replace(f"/{segment}", "/{id}", 1)

        response = await call_next(request)

        duration = time.perf_counter() - start_time
        labels = {
            "method": request.method,
            "endpoint": path,
            "status_code": str(response.status_code),
        }

        REQUEST_DURATION.labels(**labels).observe(duration)
        REQUEST_COUNT.labels(**labels).inc()

        return response
