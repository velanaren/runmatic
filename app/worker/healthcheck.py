#!/usr/bin/env python3
"""
Worker health check script.

Connects to Redis and verifies the worker is alive by checking the heartbeat key
that worker/main.py sets every 60 seconds.

Exit 0 = healthy
Exit 1 = unhealthy
"""
import os
import sys

import redis


def check() -> bool:
    redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

    try:
        client = redis.from_url(redis_url, socket_connect_timeout=3, decode_responses=True)
        client.ping()
    except Exception as exc:
        print(f"UNHEALTHY: Cannot connect to Redis: {exc}", file=sys.stderr)
        return False

    heartbeat = client.get("worker:heartbeat")
    if heartbeat is None:
        print(
            "UNHEALTHY: Worker heartbeat key missing — worker may be down or starting",
            file=sys.stderr,
        )
        return False

    print("HEALTHY: Worker heartbeat present")
    return True


if __name__ == "__main__":
    healthy = check()
    sys.exit(0 if healthy else 1)
