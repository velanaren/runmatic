#!/bin/bash
# Sprint 08 — Docker Compose v2
# Goal: Add health checks and worker service to compose stack
# Key question: How do we make depends_on wait for actual readiness, not just process start?

# === Phase 1: Review Sprint 07 baseline ===

# why: Check current compose file structure
cd infra/docker/sprint-07-compose-v1
cat docker-compose.yml
# what I saw: 3 services (api, postgres, redis), basic depends_on, no health checks
# KEY INSIGHT: depends_on only controls start order, not readiness

# === Phase 2: Extend compose file with health checks and worker ===

# why: Create Sprint 08 directory and copy baseline
mkdir -p infra/docker/sprint-08-compose-v2
cp infra/docker/sprint-07-compose-v1/docker-compose.yml infra/docker/sprint-08-compose-v2/
cd infra/docker/sprint-08-compose-v2

# why: Edit docker-compose.yml to add health checks
# (File edited manually)
# Added to postgres:
#   healthcheck:
#     test: ["CMD", "pg_isready", "-U", "runmatic"]
#     interval: 5s
#     timeout: 3s
#     retries: 5
#     start_period: 30s
#
# Added to redis:
#   healthcheck:
#     test: ["CMD", "redis-cli", "ping"]
#     interval: 5s
#     timeout: 3s
#     retries: 5
#
# Updated api depends_on:
#   postgres:
#     condition: service_healthy
#   redis:
#     condition: service_healthy

# why: Build worker image (needed before adding to compose)
cd ../../../  # back to repo root
docker build -t runmatic-worker-v1 -f app/worker/Dockerfile .
# what I saw: Worker image built successfully

# why: Add worker service to compose file
# (Edited docker-compose.yml)
# Added worker service with depends_on postgres, redis, api (all service_healthy)

# why: First attempt to start stack
cd infra/docker/sprint-08-compose-v2
docker compose up
# what I saw: postgres and redis started, API started, but worker failed
# Error: "relation runbook does not exist"
# KEY INSIGHT: Worker tried to query database before API ran migrations

# why: Add health check to API
# (Edited docker-compose.yml)
# Added to api:
#   healthcheck:
#     test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
#     interval: 30s
#     timeout: 30s
#     retries: 5
#
# Added api to worker depends_on:
#   api:
#     condition: service_healthy
# KEY INSIGHT: Worker needs schema (tables), API runs migrations, so worker depends on API

# why: Restart with complete health check configuration
docker compose down
docker compose up
# what I saw:
#   1. postgres and redis started (parallel)
#   2. Health checks began polling
#   3. postgres: "health: starting" for ~30 seconds (initialization)
#   4. redis: healthy in ~5 seconds
#   5. API started after both healthy
#   6. API ran migrations: "Running upgrade  -> 0001, Initial schema"
#   7. API became healthy
#   8. Worker started after API healthy
#   9. Worker: "Runmatic Worker starting", "APScheduler started"
# KEY INSIGHT: Dependency cascade enforced by health checks

# === Verify service status ===

# why: Check all services and their health status
docker compose ps
# what I saw:
#   NAME        STATUS                    PORTS
#   api1        Up 15 minutes (healthy)   0.0.0.0:8000->8000/tcp
#   postgres1   Up 16 minutes (healthy)   5432/tcp
#   redis1      Up 16 minutes (healthy)   6379/tcp
#   worker1     Up 15 minutes             (no health check, no status)
#
# KEY INSIGHT:
#   - postgres/redis/api show "(healthy)" status
#   - worker has no health check, so no health status
#   - Timing: postgres/redis 1 minute earlier (started first, then health checks passed)
#   - worker has no PORTS (consumer-only service, no external access needed)

# why: Check API health endpoint
curl localhost:8000/health
# what I saw: {"status":"healthy","db":"connected","cache":"connected","details":{}}
# KEY INSIGHT: All dependencies healthy, API fully operational

# === Phase 3: Test health check failure cascade ===

# why: Break postgres health check with wrong username
# (Edited docker-compose.yml)
# Changed postgres healthcheck test to: ["CMD", "pg_isready", "-U", "wronguser"]

# why: Restart to observe failure
docker compose down
docker compose up
# what I saw: Everything started normally! All healthy.
# UNEXPECTED: Health check passed even with wrong username

# why: Investigate why it didn't fail
docker exec postgres1 pg_isready -U wronguser
# what I saw: /var/run/postgresql:5432 - accepting connections
# KEY INSIGHT: pg_isready doesn't authenticate, only checks if postgres is listening

# why: Test actual authentication
docker exec postgres1 psql -U wronguser -d runmatic -c "SELECT 1"
# what I saw: psql: error: FATAL:  role "wronguser" does not exist
# KEY INSIGHT: psql actually tries to authenticate and correctly fails

# why: Use correct failing health check with psql
# (Edited docker-compose.yml)
# Changed postgres healthcheck to: ["CMD-SHELL", "psql -U wronguser -d runmatic -c 'SELECT 1' || exit 1"]

# why: Restart to observe correct failure behavior
docker compose down
docker compose up
# what I saw:
#   - postgres and redis started
#   - postgres showed "health: starting"
#   - API and worker never started (waiting for postgres healthy)
#   - After ~50 seconds: "dependency failed to start: container postgres1 is unhealthy"
#
# KEY INSIGHT:
#   - Health check failed as expected
#   - API and worker blocked (depends_on: service_healthy working correctly)
#   - Timeout: 5 retries × ~10 seconds = 50 seconds before Compose gave up

# why: Check service status during failure
docker compose ps
# what I saw:
#   postgres1   Up 21 seconds (health: starting)
#   redis1      Up 21 seconds (healthy)
#   (api and worker not started)
# KEY INSIGHT: One unhealthy service blocks entire dependency chain

# why: Fix health check back to correct configuration
# (Edited docker-compose.yml)
# Changed postgres healthcheck to: ["CMD", "pg_isready", "-U", "runmatic"]

# why: Restart with correct health check
docker compose down
docker compose up -d
# what I saw: All services started successfully, all healthy

# why: Verify all healthy
docker compose ps
# what I saw: All services showing (healthy) status
# KEY INSIGHT: Correct health check allows proper startup sequence

# === Bonus Challenge: Redis bind misconfiguration ===

# why: Simulate redis listening only on localhost
# (Edited docker-compose.yml)
# Added to redis service: command: redis-server --bind 127.0.0.1

# why: Restart to observe the issue
docker compose down
docker compose up
# what I saw:
#   - Redis started: "Ready to accept connections tcp"
#   - Redis health check passed
#   - API started but showed degraded

# why: Check service status
docker compose ps
# what I saw:
#   postgres1   Up (healthy)
#   redis1      Up (healthy)  ← Health check passed!
#   api1        Up (healthy)
#   worker1     exited (crashed)
# KEY INSIGHT: Redis shows healthy but API can't connect

# why: Check API health endpoint
curl localhost:8000/health
# what I saw: {"status":"degraded","db":"connected","cache":"disconnected",
#              "details":{"cache_error":"Error 111 connecting to redis:6379. 111."}}
# KEY INSIGHT: Error 111 = Connection refused (DNS worked, but connection rejected)

# why: Check worker logs
docker compose logs worker1
# what I saw: {"level": "ERROR", "message": "Cannot connect to Redis — aborting"}
#             worker1 exited with code 1
# KEY INSIGHT: Worker crashed entirely (no retry logic like API has)

# why: Test redis health check inside container
docker exec redis1 redis-cli ping
# what I saw: PONG
# KEY INSIGHT: Health check succeeds inside the container (localhost available)

# why: Test redis connection from API container
docker exec api1 nc -zv redis 6379
# what I saw: Connection refused
# KEY INSIGHT: From another container, redis is unreachable

# ROOT CAUSE DIAGNOSIS:
# Redis with --bind 127.0.0.1 listens only on localhost inside its own container.
# Health check runs INSIDE redis container → localhost works → PONG → healthy
# API tries to connect from DIFFERENT container → resolves redis:6379 to network IP →
# → but Redis isn't listening on network interface → connection refused
#
# This is a false positive: service shows "healthy" in its own context but unreachable from others.

# WHAT I MISSED:
# Didn't complete the fix:
# 1. Remove --bind 127.0.0.1 from redis command
# 2. Restart services
# 3. Verify curl localhost:8000/health shows "cache":"connected"
#
# Diagnosis without verification doesn't resolve the incident.

# === Cleanup ===

# why: Stop all services
docker compose down

# === Key Takeaways ===
# 1. Health checks enable condition: service_healthy (wait for actual readiness)
# 2. Health check anatomy: test, interval, timeout, retries, start_period
# 3. start_period for databases: initialization takes longer than steady-state restarts
# 4. pg_isready (connectivity) vs psql (authentication) — choose based on app needs
# 5. Worker depends on API (needs schema, API runs migrations)
# 6. Health checks can give false positives (redis bound to 127.0.0.1)
# 7. One unhealthy service blocks entire dependency chain (correct behavior)
# 8. Cascading dependencies: postgres → redis → api → worker
# 9. Complete the fix: diagnosis + implementation + verification
