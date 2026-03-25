# RUNMATIC.md — Application Architecture Contract
*Generated and maintained by Claude.*
*Vela reads this thoroughly in Session 0B before touching infra/.*
*Updated whenever application architecture changes.*
*This is your reference for everything about the application you are deploying.*

---

## The Problem Runmatic Solves

Runbooks go stale. Every SRE team has them: documents that were accurate when written, now referencing tools that were deprecated, escalation paths to people who left, Kubernetes versions from three years ago. Nobody updates them because there's no forcing function — no visibility into staleness, no accountability when they fail during an incident, no integration with the systems they describe.

Runmatic creates that forcing function:
- Every runbook has a "last verified" date with a prominent staleness indicator
- Deployment events automatically flag linked runbooks for review
- Incidents are linked to the runbooks used — building a history of which runbooks were accurate
- Action items from incidents track directly back to runbook improvements
- The dashboard gives every team a continuous view of their runbook health

---

## Architecture Diagram

```
                         ┌──────────────────────────────┐
                         │         BROWSER               │
                         │    (User's computer)          │
                         └──────────┬───────────────────┘
                                    │ HTTP :3000
                         ┌──────────▼───────────────────┐
                         │    FRONTEND (React + Nginx)   │
                         │                               │
                         │  Nginx serves static files    │
                         │  Nginx proxies /api/* →       │
                         │        http://api:8000        │
                         └──────────┬───────────────────┘
                                    │ HTTP :8000 (via Docker DNS)
                         ┌──────────▼───────────────────┐
                         │       API (FastAPI)            │
                         │    REST + Auth + Webhooks     │
                         │    Business logic layer       │
                         └──────┬──────────┬────────────┘
                                │          │
              ┌─────────────────▼──┐  ┌────▼──────────────┐
              │    POSTGRES (15)   │  │    REDIS (7)        │
              │    Port: 5432      │  │    Port: 6379       │
              │                   │  │                     │
              │  Runbooks         │  │  JWT sessions       │
              │  Services         │  │  API response cache │
              │  Incidents        │  │  Job queue (rq)     │
              │  Action items     │  │  Rate limiting      │
              │  Deployments      │  │                     │
              └────────────────────┘  └──────┬────────────┘
                                             │ Reads queue
                         ┌───────────────────▼────────────┐
                         │      WORKER (APScheduler)       │
                         │                                 │
                         │  Hourly: staleness recalc       │
                         │  Queue: deployment webhooks     │
                         │  Queue: notifications           │
                         │  Daily: session/token cleanup   │
                         └─────────────────────────────────┘
```

---

## Service Reference — Complete Detail

### SERVICE 1: API (`app/api/`)

| Property | Value |
|----------|-------|
| Technology | Python 3.11, FastAPI, SQLAlchemy 2.0, Alembic, Pydantic v2 |
| Port | 8000 |
| Health endpoint | `GET /health` |
| Health response | `{"status":"healthy","db":"connected","cache":"connected"}` |
| Startup time | ~3–5 seconds (waits for DB connection, runs migrations) |
| Startup command | `uvicorn app.main:app --host 0.0.0.0 --port 8000` |

**Required environment variables:**

| Variable | Example | Notes |
|----------|---------|-------|
| `DATABASE_URL` | `postgresql+asyncpg://runmatic:password@postgres:5432/runmatic` | Hostname must match service name on Docker network |
| `REDIS_URL` | `redis://redis:6379/0` | Hostname must match service name on Docker network |
| `SECRET_KEY` | `[32+ random chars]` | Used for JWT signing. Never commit the real value. |
| `ENVIRONMENT` | `development` | Controls log level defaults and CORS behavior |
| `LOG_LEVEL` | `INFO` | `DEBUG` for development, `INFO` for production |
| `CORS_ORIGINS` | `http://localhost:3000` | Comma-separated list of allowed origins |

**What breaks if API goes down:**
- UI shows empty state — no data loads, all API calls fail
- Webhook events are lost (no queue at the API level — they just 404)
- Users cannot create, update, or verify runbooks

**What keeps working if API goes down:**
- Frontend still loads (Nginx serves static files without the API)
- Worker continues processing any jobs already in the Redis queue
- Database data is completely safe
- Redis data is unaffected

---

### SERVICE 2: WORKER (`app/worker/`)

| Property | Value |
|----------|-------|
| Technology | Python 3.11, APScheduler, rq (Redis Queue) |
| Port | None — no HTTP server |
| Health check | `python worker/healthcheck.py` (checks Redis connection + scheduler status) |
| Startup command | `python worker/main.py` |

**Required environment variables:**

| Variable | Example | Notes |
|----------|---------|-------|
| `DATABASE_URL` | Same as API | Needs DB access for staleness calculation |
| `REDIS_URL` | Same as API | Job queue source |
| `LOG_LEVEL` | `INFO` | |
| `STALENESS_THRESHOLD_DAYS` | `7` | Days before a runbook is considered stale |
| `STALENESS_CHECK_INTERVAL` | `3600` | Seconds between staleness recalculations |

**What the worker does:**
- **Every hour:** Scans all runbooks, recalculates `staleness_days`, updates status (fresh/warning/stale), writes back to database
- **On deployment webhook events:** Reads from Redis queue, finds all runbooks linked to the deployed service, marks them as "needs review"
- **On notification queue:** Sends Slack notifications (stubbed in Act 1, real in Sprint 26) when staleness exceeds threshold
- **Daily at 2am:** Cleans up expired JWT sessions and old one-time tokens from the database

**What breaks if Worker goes down:**
- Staleness scores stop updating — the dashboard shows stale numbers
- Deployment webhook events queue up in Redis but are not processed (no data loss — they'll process when worker restarts)
- Notification sending stops
- Session cleanup stops (minor — Redis TTLs handle most of this)

**What keeps working:**
- API fully functional
- UI fully functional — users can still create, update, and manually verify runbooks
- Database is safe

---

### SERVICE 3: FRONTEND (`app/frontend/`)

| Property | Value |
|----------|-------|
| Technology | React 18, TypeScript, Vite, TailwindCSS |
| Runtime | Nginx (serves compiled static files) |
| Port | 3000 |
| Build output | `dist/` (compiled by Vite) |
| Nginx config | `app/frontend/nginx.conf` |

**Nginx routing (critical for infra work):**
- `GET /` and all non-API routes → serve `dist/index.html` (React handles client-side routing)
- `GET /api/*` → proxy to `http://api:8000` (Docker DNS resolution)
- Static assets (`*.js`, `*.css`, images) → serve from `dist/`

**Environment variables — BUILD TIME only:**

| Variable | Value | Notes |
|----------|-------|-------|
| `VITE_API_URL` | `/api` | Relative path — Nginx handles the actual proxy |

**There are no runtime environment variables.** The compiled output is static files. Configuration baked in at build time cannot be changed without rebuilding.

**Why the browser can't reach `api:8000` directly:**
The browser runs on your laptop, outside Docker. Docker DNS (`api` → container IP) only works inside the Docker network. Nginx runs inside Docker — it can resolve `api:8000`. The browser talks to Nginx; Nginx talks to the API. The browser never needs to know about Docker.

**What breaks if Frontend goes down:**
- Users see nothing — the UI is inaccessible
- API still fully works (direct calls via curl or Postman still function)
- All data in the database is safe

---

### SERVICE 4: POSTGRES (`postgres`)

| Property | Value |
|----------|-------|
| Image | `postgres:15-alpine` |
| Port | 5432 (internal only — never publish to host in production) |
| Data directory | `/var/lib/postgresql/data` (MUST be mounted as a volume) |
| Health check | `pg_isready -U runmatic -d runmatic` |
| Init behavior | Creates database and user on first start if they don't exist |

**Required environment variables:**

| Variable | Example |
|----------|---------|
| `POSTGRES_USER` | `runmatic` |
| `POSTGRES_PASSWORD` | `[strong password]` |
| `POSTGRES_DB` | `runmatic` |

**Database schema (for infra context — not full DDL):**

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `users` | Authentication | id, email, hashed_password, created_at |
| `services` | Monitored services | id, name, description, owner_team |
| `runbooks` | Core entity | id, title, content_md, service_id, last_verified_at, staleness_days, status |
| `runbook_steps` | Checklist items | id, runbook_id, order, description, completed_at |
| `incidents` | Incident records | id, title, severity, started_at, resolved_at, service_id |
| `incident_runbooks` | Junction table | incident_id, runbook_id, was_accurate |
| `action_items` | Post-incident tasks | id, incident_id, runbook_id, description, status, due_date |
| `deployments` | Webhook events | id, service_id, version, deployed_at, triggered_by |

**Critical:** Without a volume at `/var/lib/postgresql/data`, ALL DATA IS LOST every time the container stops. Every runbook, every incident, every action item — gone. This is the most important thing to understand for Sprint 05.

---

### SERVICE 5: REDIS (`redis`)

| Property | Value |
|----------|-------|
| Image | `redis:7-alpine` |
| Port | 6379 (internal only) |
| Health check | `redis-cli ping` |
| Persistence | None required — all Redis data is intentionally ephemeral |
| Auth | None in development (add requirepass in production) |

**What Redis stores:**

| Key pattern | Content | TTL |
|-------------|---------|-----|
| `session:{user_id}` | JWT session data | 24 hours |
| `rq:queue:default` | Job queue for deployment events | Until processed |
| `rq:queue:notifications` | Job queue for Slack/email sends | Until processed |
| `cache:runbooks:list` | Cached runbook list response | 60 seconds |
| `ratelimit:{ip}` | Request count for rate limiting | 1 minute |

**What breaks if Redis goes down:**
- All logged-in users get 401 errors (sessions invalidated)
- Deployment webhook events are lost (queue unavailable)
- API response caching disabled (slower but still functional)
- Rate limiting disabled (minor security concern)

**What keeps working:**
- Database reads and writes still work
- Worker's scheduled jobs (staleness recalc) still run — they query the DB directly
- New users can still log in once Redis recovers (sessions re-created)

---

## Startup Order & Dependencies

```
1. postgres    ← starts first, health check: pg_isready
                  ↓ (must be HEALTHY before API starts)
2. redis       ← starts in parallel with postgres, health check: redis-cli ping
                  ↓ (must be HEALTHY before API and Worker start)
3. api         ← starts after postgres AND redis are healthy
                  On startup: runs Alembic migrations, then starts uvicorn
                  ↓ (must be STARTED before frontend, though frontend builds independently)
4. worker      ← starts after postgres AND redis are healthy (parallel with api)
5. frontend    ← starts after api is started (Nginx needs api for proxy, but serves static without it)
```

**Critical startup behavior:** The API runs Alembic migrations on startup. If PostgreSQL isn't ready when the API starts, the migration fails and the API crashes. The health check `condition: service_healthy` in Compose prevents this.

---

## Port Reference

| Service | Internal Port | Publish to Host? | Accessed by |
|---------|-------------|-----------------|-------------|
| frontend | 3000 | ✅ Yes — browser access | Browser |
| api | 8000 | Dev: yes / Prod: no | Frontend (via Nginx proxy), Worker |
| postgres | 5432 | ❌ Never | API, Worker |
| redis | 6379 | ❌ Never | API, Worker |
| worker | — | ❌ No port | Queue consumer only |

---

## API Surface Reference

```
Authentication
  POST   /api/auth/login              Get JWT token
  POST   /api/auth/logout             Invalidate session

Services
  GET    /api/services                List all services
  POST   /api/services                Create service
  GET    /api/services/{id}           Get service detail

Runbooks
  GET    /api/runbooks                List runbooks (with staleness filter)
  POST   /api/runbooks                Create runbook
  GET    /api/runbooks/{id}           Get runbook with steps and history
  PUT    /api/runbooks/{id}           Update runbook content
  POST   /api/runbooks/{id}/verify    Mark as verified — resets staleness clock
  GET    /api/runbooks/{id}/history   Version history

Incidents
  GET    /api/incidents               List incidents
  POST   /api/incidents               Create incident
  PUT    /api/incidents/{id}/resolve  Mark incident resolved
  POST   /api/incidents/{id}/runbooks Link a runbook to this incident

Action Items
  GET    /api/action-items            List open action items
  POST   /api/action-items            Create action item
  PUT    /api/action-items/{id}       Update status

Webhooks
  POST   /api/webhooks/deployment     Receive deployment event → queues runbook review jobs

Observability
  GET    /health                      Health check (for Docker/K8s health checks)
  GET    /metrics                     Prometheus metrics (for Sprint 24)
```

---

## Actual Implementation Details (Session 0A complete — 2026-03-17)

### Pinned dependency versions

**API (`app/api/requirements.txt`):**
- fastapi==0.109.2, uvicorn[standard]==0.27.1
- sqlalchemy==2.0.28, asyncpg==0.29.0, alembic==1.13.1
- pydantic==2.6.4, pydantic-settings==2.2.1
- python-jose[cryptography]==3.3.0, passlib[bcrypt]==1.7.4
- redis==5.0.3, rq==1.16.2, prometheus-client==0.20.0

**Worker (`app/worker/requirements.txt`):**
- sqlalchemy==2.0.28, psycopg2-binary==2.9.9 (sync driver — worker uses sync SQLAlchemy)
- pydantic-settings==2.2.1, redis==5.0.3, rq==1.16.2, apscheduler==3.10.4

**Frontend (`app/frontend/package.json`):**
- react==18.2.0, react-dom==18.2.0, react-router-dom==6.22.3
- axios==1.6.8, react-markdown==9.0.1
- vite==5.2.0, tailwindcss==3.4.3, typescript==5.4.2

### Architectural decisions made

1. **Worker uses sync SQLAlchemy + psycopg2**, not async. The worker's APScheduler and rq
   don't benefit from async, and sync code is simpler here. The DATABASE_URL (asyncpg format)
   is converted automatically in `worker/config.py` via `.replace("postgresql+asyncpg://", "postgresql+psycopg2://")`.

2. **Alembic lives in `app/api/migrations/`** (canonical). `app/db/alembic.ini` points to the
   same migration files via relative path — so migrations can be run from either service context.
   The API runs `alembic upgrade head` automatically on startup via its lifespan handler.

3. **JWT sessions are double-validated**: the JWT signature is verified AND the session is
   confirmed present in Redis. This means tokens can be invalidated server-side (logout works
   immediately). Redis key: `session:{user_id}`, TTL: 24 hours.

4. **Token stored in memory on frontend** (JS module variable, not localStorage). On browser
   refresh, the token is lost and the user must log in again. This is intentional — no XSS
   token theft via localStorage.

5. **Worker heartbeat**: worker/main.py sets `worker:heartbeat` in Redis every 60 seconds.
   `healthcheck.py` checks this key exists to confirm the worker is alive.

6. **rq queues**: `default` (deployment webhooks) and `notifications` (stub for Sprint 26).
   Both run in the same rq Worker inside a background thread in worker/main.py.

7. **Prometheus metrics** expose: `api_request_duration_seconds` (histogram with path
   normalization to avoid high cardinality from `/runbooks/123`), `api_requests_total` (counter),
   `runbook_total` (gauge by status — updated on verify).

8. **Dashboard route** at `GET /api/dashboard` — not in the original API surface spec but added
   to support the frontend dashboard stats panel without N+1 queries.

---

## Key Facts for Each Sprint

**Sprint 03 (Dockerfile):**
The API starts with `uvicorn app.main:app --host 0.0.0.0 --port 8000`. It needs `requirements.txt` installed. The entry point is `app/api/main.py`. Use exec form CMD.

**Sprint 04 (Environment):**
The API has 6 required env vars. `DATABASE_URL` and `SECRET_KEY` are sensitive. `LOG_LEVEL` and `ENVIRONMENT` are not. `.env.example` should document all 6 with placeholder values.

**Sprint 05 (Volumes):**
PostgreSQL data lives at `/var/lib/postgresql/data`. Without a volume mounted here, every container restart loses all runbooks, incidents, and action items. No other service needs a persistent volume.

**Sprint 06 (Networking):**
`DATABASE_URL` uses hostname `postgres` (the container name on the network). `REDIS_URL` uses hostname `redis`. These must exactly match the `--name` flag or Compose service name.

**Sprint 07–08 (Compose):**
Startup order matters. API must wait for postgres to be healthy (not just started). `depends_on: postgres: condition: service_healthy`. The worker has the same requirement for both postgres and redis.

**Sprint 09 (Frontend):**
Nginx proxies `/api/*` to `http://api:8000`. The `api` hostname resolves via Docker DNS because both containers are on the same Compose network.

**Sprint 16 (K8s Secrets):**
`DATABASE_URL`, `REDIS_URL`, `SECRET_KEY` → K8s Secrets. `LOG_LEVEL`, `ENVIRONMENT`, `CORS_ORIGINS` → ConfigMaps.

**Sprint 28–30 (AWS):**
`DATABASE_URL` will change to point at RDS in Sprint 30. `REDIS_URL` stays in K8s (Redis runs in EKS). `SECRET_KEY` moves to AWS Secrets Manager in Sprint 31.
