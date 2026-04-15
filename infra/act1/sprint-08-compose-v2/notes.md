# Sprint 08 — Docker Compose v2 — Notes

## Phase 1 — The Hook

**Claude's Explanation:**

In Sprint 07 you discovered that `depends_on` only controls **start order**, not **readiness**. Postgres takes 2-3 seconds after its process starts before it's ready to accept connections. The API might crash trying to connect during that window.

**Health checks fix this.** A health check is a command that runs every few seconds: "Are you ready?" For postgres: `pg_isready -U runmatic -d runmatic`. For redis: `redis-cli ping`. If it returns success, the service is healthy.

`depends_on` with `condition: service_healthy` means: **"Don't start the API until postgres has passed its health check."** Not "process exists" but "service is actually ready."

This is how you've diagnosed production incidents — you don't just check if the process is running (`ps aux | grep postgres`), you check if it's accepting connections (`psql -c "SELECT 1"`). Health checks automate that judgment.

**First Check:**

Reviewed Sprint 07 compose file:
- 3 services: api, postgres, redis
- Basic `depends_on` without health check conditions
- No health checks defined
- Worker service not included yet

---

## Phase 2 — The Build

**Done Condition:** 4 services running (api, postgres, redis, worker). Health checks configured. API waits for postgres healthy, worker waits for postgres, redis, and API healthy. `docker compose ps` shows "healthy" status.

**My Work:**

Created Sprint 08 directory and copied Sprint 07 compose file:
```bash
mkdir -p infra/docker/sprint-08-compose-v2
cp infra/docker/sprint-07-compose-v1/docker-compose.yml infra/docker/sprint-08-compose-v2/
cd infra/docker/sprint-08-compose-v2
```

**Changes made:**

### 1. Added health check to postgres

```yaml
postgres:
  healthcheck:
    test: ["CMD", "pg_isready", "-U", "runmatic"]
    interval: 5s       # check every 5 seconds
    timeout: 3s        # wait max 3 seconds for response
    retries: 5         # fail after 5 consecutive failures
    start_period: 30s  # give postgres 30 seconds before counting failures
```

**Why start_period matters:** On first startup, postgres initializes the database (creates files, runs initdb). This takes longer than steady-state restarts. `start_period` gives it breathing room before health check failures start counting against the `retries` limit.

### 2. Added health check to redis

```yaml
redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
    timeout: 3s
    retries: 5
```

**No start_period needed:** Redis starts almost instantly. No initialization overhead like postgres.

### 3. Updated api depends_on to use health check conditions

```yaml
api:
  depends_on:
    postgres:
      condition: service_healthy  # wait for health check to pass
    redis:
      condition: service_healthy
```

### 4. Added health check to api

Initially didn't include this, but discovered it was needed when the worker failed.

```yaml
api:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    interval: 30s
    timeout: 30s
    retries: 5
```

**Why the API needs a health check:** The worker needs the database **schema** to exist, not just the database server running. The API runs Alembic migrations on startup, which create the schema. Worker must wait for API to complete migrations and be healthy.

### 5. Added worker service

First attempt failed with `relation runbook does not exist` error. The worker tried to query the database before the API ran migrations.

```yaml
worker:
  image: runmatic-worker-v1
  container_name: worker1
  environment:
    DATABASE_URL: postgresql+asyncpg://runmatic:devpassword@postgres:5432/runmatic
    REDIS_URL: redis://redis:6379/0
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
    api:
      condition: service_healthy  # CRITICAL: worker needs schema, API runs migrations
```

**Why worker depends on API:** Worker queries database tables immediately on startup. Those tables don't exist until migrations run. Migrations run inside the API startup. Therefore: worker must wait for API to be healthy (migrations complete).

**Does worker need published ports?** No. Worker is a consumer-only service — it processes background jobs from the Redis queue. No external access needed.

**Worker image creation:**

Had to build the worker image first:
```bash
docker build -t runmatic-worker-v1 -f app/worker/Dockerfile .
```

---

## First Startup

```bash
docker compose up
```

**Startup sequence observed:**

1. Network and volume created
2. postgres and redis started in parallel
3. Health checks began polling immediately
4. postgres showed "health: starting" for ~30 seconds (initialization + start_period)
5. redis became healthy in ~5 seconds
6. API started after both postgres and redis were healthy
7. API ran Alembic migrations: "Running upgrade  -> 0001, Initial schema — all tables"
8. API became healthy after migrations completed
9. Worker started only after API became healthy
10. Worker logged: "Runmatic Worker starting", "Redis connection established", "APScheduler started"

**Logs showing the dependency cascade:**

```
postgres1  | 2026-04-11 11:53:47.400 UTC [1] LOG:  database system is ready to accept connections
redis1     | 1:M 11 Apr 2026 11:53:46.589 * Ready to accept connections tcp
api1       | {"message": "Running Alembic migrations", ...}
api1       | INFO  [alembic.runtime.migration] Running upgrade  -> 0001, Initial schema
worker1    | {"message": "Runmatic Worker starting", ...}
worker1    | {"message": "APScheduler started", ...}
```

**Service status check:**

```bash
docker compose ps
```

**Result:**
```
NAME        IMAGE                COMMAND                  SERVICE    CREATED          STATUS                    PORTS
api1        runmatic-api-v1      "uvicorn app.main:ap…"   api        16 minutes ago   Up 15 minutes (healthy)   0.0.0.0:8000->8000/tcp
postgres1   postgres:15-alpine   "docker-entrypoint.s…"   postgres   16 minutes ago   Up 16 minutes (healthy)   5432/tcp
redis1      redis:7-alpine       "docker-entrypoint.s…"   redis      16 minutes ago   Up 16 minutes (healthy)   6379/tcp
worker1     runmatic-worker-v1   "python -m worker.ma…"   worker     16 minutes ago   Up 15 minutes
```

**Key observations:**
- postgres, redis, api all show "(healthy)" status
- worker shows no health status because no health check defined
- Timing: postgres/redis started first (16 min ago), then api/worker (15 min ago) after health checks passed
- worker has no published ports (no PORTS column entry)

**API health check:**

```bash
curl localhost:8000/health
```

**Result:**
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**Done condition met.** All 4 services running, health checks passing, dependencies enforced correctly.

---

## Phase 3 — The Challenge

**Claude's Challenge:**

Deliberately break the postgres health check and observe the dependency cascade.

**My Investigation:**

### Attempt 1: Wrong username in pg_isready

Changed postgres health check:
```yaml
test: ["CMD", "pg_isready", "-U", "wronguser"]
```

**Restarted:**
```bash
docker compose down
docker compose up
```

**Result:** Everything started normally! All containers healthy.

**Why it didn't fail:** Investigated with `docker exec`:

```bash
docker exec postgres1 pg_isready -U wronguser
# Output: /var/run/postgresql:5432 - accepting connections
```

`pg_isready` doesn't actually authenticate — it only checks if postgres is listening on the socket. The username doesn't matter. It succeeded even with a wrong username.

**Testing actual authentication:**
```bash
docker exec postgres1 psql -U wronguser -d runmatic -c "SELECT 1"
# Output: psql: error: FATAL:  role "wronguser" does not exist
```

This command actually tries to authenticate and correctly fails.

### Attempt 2: Correct failing health check with psql

Changed postgres health check to:
```yaml
test: ["CMD-SHELL", "psql -U wronguser -d runmatic -c 'SELECT 1' || exit 1"]
```

**Restarted:**
```bash
docker compose down
docker compose up
```

**Result:**

postgres and redis started, but postgres health check failed:

```bash
docker compose ps
```

**Output:**
```
NAME        STATUS
postgres1   Up 21 seconds (health: starting)
redis1      Up 21 seconds (healthy)
```

API and worker never started. They were waiting for postgres to become healthy.

**Waited ~50 seconds, then:**

```
postgres1  | FATAL:  role "wronguser" does not exist
Gracefully stopping... (press Ctrl+C again to force)
dependency failed to start: container postgres1 is unhealthy
```

**Timeout calculation:**
- 5 retries (from health check config)
- 10 seconds between attempts (5s interval + 3s timeout + ~2s processing)
- Total: ~50 seconds before Compose gave up

**What this proved:**

1. **`pg_isready` vs `psql`:** `pg_isready` only checks if postgres accepts connections. `psql` actually authenticates. For production, choose based on what your application needs.

2. **`condition: service_healthy` works:** API and worker never started. They waited for postgres to pass health checks. The dependency graph held correctly.

3. **Failure propagates correctly:** One unhealthy service blocks all dependent services. This is exactly what you want — don't start the app if the database isn't ready.

**Fixed health check back:**
```yaml
test: ["CMD", "pg_isready", "-U", "runmatic"]
```

Restarted, all services healthy.

---

## Phase 4 — Explanation

**Claude's Question:**

Explain Docker Compose health checks in 3 sentences. Pretend you're explaining it to an on-call engineer who's been restarting services manually and wants to automate it. Don't look anything up.

**My Answer:**

Health checks help to check if the container is healthy and it is doing the intended job.
- container running + passes health check = Healthy
- container running + fails health check = Unhealthy

Unhealthy can be because of 2 issues:
1. Container crashes
2. The functionality is not as expected

Health checks help to check service readiness before starting a service to check all its dependent services if they are healthy.

`condition: service_healthy` — container passes the health check — if this is defined, service will not start if the dependent container does not pass the health check.

`condition: service_started` — container is running — if this is defined, service will start even if the dependent services are just running (not required to do their intended function).

**Claude's Feedback:**

Nailed the critical distinction: `service_healthy` waits for health check to pass (container doing its job) vs `service_started` just waits for process to exist (container running, maybe not ready).

Identified the two failure modes: crash (container dies) vs degraded (container alive but broken functionality).

Gap: Didn't mention health check parameters (interval, retries, timeout, start_period) in explanation, though I configured them correctly.

---

## Bonus Challenge — Redis Bind Misconfiguration

**Challenge:**

All 4 services start. `docker compose ps` shows redis healthy. But API health returns:
```json
{"status":"degraded","cache":"disconnected","details":{"cache_error":"Error -2 connecting to redis:6379"}}
```

Redis is running. Health check passes. Why can't the API reach it?

**My Investigation:**

### Hypothesis

This situation may happen when the health check ping works inside the container, but anything outside the container can't reach redis even though it's on the same network.

It may be due to the `bind` configuration, where redis accepts connections only from its own container and not from other containers.

### Simulation

Added to redis service in compose file:
```yaml
redis:
  command: redis-server --bind 127.0.0.1
```

**Restarted:**
```bash
docker compose down
docker compose up
```

**Observed:**

Redis started and health check passed:
```
redis1     | 1:M 11 Apr 2026 14:30:24.831 * Ready to accept connections tcp
```

```bash
docker compose ps
```

**Output:**
```
NAME        STATUS
postgres1   Up (healthy)
redis1      Up (healthy)  ← Health check passed
api1        Up (healthy)
```

But API showed degraded:
```bash
curl localhost:8000/health
```

**Result:**
```json
{"status":"degraded","db":"connected","cache":"disconnected","details":{"cache_error":"Error 111 connecting to redis:6379. 111."}}
```

Worker crashed:
```
worker1    | {"level": "ERROR", "message": "Cannot connect to Redis — aborting"}
worker1 exited with code 1
```

**Root Cause:**

Redis configured with `--bind 127.0.0.1` listens only on localhost inside its own container.

- **Health check passes:** `redis-cli ping` runs INSIDE the redis container via the healthcheck test. From inside the container, `127.0.0.1` is available.
- **API can't connect:** API is in a different container. It resolves `redis:6379` to the redis container's network IP (172.x.x.x), but Redis isn't listening on that interface — only on 127.0.0.1.

**Error code meaning:**
- `Error -2`: Name or service not known (DNS failure)
- `Error 111`: Connection refused (DNS worked, but connection rejected)

My simulation showed Error 111 — the API resolved `redis` successfully, but Redis rejected the connection because it's not listening on the network interface.

**What I missed:**

Didn't complete the fix and verify it works. Should have:
1. Removed `--bind 127.0.0.1` from the command
2. Restarted services
3. Verified `curl localhost:8000/health` returns `"cache":"connected"`

**Bonus Score: 7/10**
- Diagnosis: 5/5 (correctly identified bind issue)
- Fix: 2/5 (identified what's wrong but didn't implement and verify)

---

## Key Takeaways

1. **Health checks test service readiness, not just process existence** — `condition: service_healthy` waits for actual readiness
2. **Health check anatomy:** `test`, `interval`, `timeout`, `retries`, `start_period`
3. **start_period for databases:** Gives initialization time before failures count against retries
4. **service_healthy vs service_started:** Healthy waits for check to pass, started just waits for process
5. **pg_isready vs psql:** pg_isready checks connectivity, psql checks authentication. Choose based on what your app needs.
6. **Worker depends on API for schema:** Migrations create tables, API runs migrations, worker needs tables — therefore worker depends on API
7. **Health checks can give false positives:** Redis bound to 127.0.0.1 passes its own health check but unreachable from other containers
8. **Cascading dependencies:** One unhealthy service blocks all dependent services — exactly what you want
9. **Health checks → Kubernetes probes:** These concepts (liveness, readiness) map directly to K8s in Sprint 14
10. **Complete the fix:** Diagnosis without verification doesn't resolve the incident
