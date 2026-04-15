# Sprint 07 — Docker Compose v1 — Notes

## Phase 1 — The Hook

**Claude's Explanation:**

You've been running containers with `docker run` commands. Fifteen flags. Two terminals. If you forget the network name, the API can't find postgres. If you forget the volume mount, all data disappears.

**Docker Compose is Autosys for containers.** You define the job chain in one file — which services, their dependencies, their config. Compose figures out the start order, creates the network automatically, manages the volumes. One command: `docker compose up`. The entire stack comes alive.

The magic: Compose creates a **dedicated network for your project automatically**. That's why you didn't have to run `docker network create` in Sprint 06 — Compose does it. Every service in the file joins that network and can find every other service by name.

**First Check:**

```bash
docker compose version
```

**My Result:**
```
Docker Compose version v2.38.2-desktop.1
```

I have v2 installed. The command is `docker compose` (space, not hyphen).

---

## Phase 2 — The Build

**Done Condition:** `docker compose up` starts API + PostgreSQL + Redis. `curl localhost:8000/health` returns healthy with db and cache connected. Stop it, restart it, data still there.

**My Work:**

Created directory structure:
```bash
mkdir -p infra/docker/sprint-07-compose-v1
```

**Scaffold provided by Claude:**

```yaml
services:
  postgres:
    image: postgres:15
    # TODO(vela): container name
    environment:
      # TODO(vela): postgres needs POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
    volumes:
      # TODO(vela): named volume mount at /var/lib/postgresql/data
    # TODO(vela): does postgres need published ports?

  api:
    image: runmatic-api:latest
    # TODO(vela): container name
    ports:
      # TODO(vela): publish API port to host
    environment:
      # TODO(vela): DATABASE_URL — use the postgres service name as hostname
      # TODO(vela): SECRET_KEY, other API env vars
    depends_on:
      # TODO(vela): which service must start before this one?
    # TODO(vela): does api need a volume?

volumes:
  # TODO(vela): define the named volume for postgres
```

**Key questions I answered:**

1. **Published ports:** postgres does NOT need `-p 5432:5432` because only the API needs to reach it, and API is on the same network. I only published 8000 for the API because browsers need external access.

2. **DATABASE_URL:** Used `postgres` as the hostname (the service name), not localhost or an IP.

3. **depends_on:** API depends on postgres and redis — ensures they start first.

4. **Named volumes:** Declared `postgres-data:` in top-level `volumes:` section, then mounted it in the postgres service.

**My docker-compose.yml:**

```yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: postgres1
    environment:
      POSTGRES_DB: runmatic
      POSTGRES_USER: runmatic
      POSTGRES_PASSWORD: devpassword
    volumes:
      - postgres-data:/var/lib/postgresql/data
 
  redis:
    image: redis:7-alpine
    container_name: redis1

  api:
    image: runmatic-api-v1
    container_name: api1
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql+asyncpg://runmatic:devpassword@postgres:5432/runmatic
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: dev-secret-key
    depends_on:
      - postgres
      - redis

volumes:
  postgres-data:
```

**First Run:**

```bash
cd infra/docker/sprint-07-compose-v1
docker compose up
```

**What I Saw:**

```
[+] Running 3/3
 ✔ Container redis1     Created
 ✔ Container postgres1  Created
 ✔ Container api1       Created
Attaching to api1, postgres1, redis1
```

Redis and postgres started first (in parallel), then API started. Compose understood the dependency order from `depends_on`.

**Key observations from logs:**
- postgres: "Database directory appears to contain a database; Skipping initialization" — volume persisted from Sprint 06!
- postgres: "database system is ready to accept connections"
- api: "Running Alembic migrations" then "Started server process"

**Health Check:**

```bash
curl localhost:8000/health
```

**Result:**
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**Service Status:**

```bash
docker compose ps
```

**Result:**
```
NAME        IMAGE                COMMAND                  SERVICE    CREATED         STATUS         PORTS
api1        runmatic-api-v1      "uvicorn app.main:ap…"   api        2 minutes ago   Up 2 minutes   0.0.0.0:8000->8000/tcp
postgres1   postgres:15-alpine   "docker-entrypoint.s…"   postgres   2 minutes ago   Up 2 minutes   5432/tcp
redis1      redis:7-alpine       "docker-entrypoint.s…"   redis      2 minutes ago   Up 2 minutes   6379/tcp
```

**My observations:**
- **Name vs Service:** Container name (postgres1) is just a label. Service name (postgres) is the DNS hostname other containers use.
- **Ports column:** API shows `0.0.0.0:8000->8000/tcp` (published to host). postgres and redis show `5432/tcp` and `6379/tcp` (internal only, no host mapping).
- **Why no published ports for postgres/redis:** They're on the same Compose network. API connects internally to `postgres:5432` and `redis:6379`. No host access needed.

**Done condition met.**

---

## Testing Persistence

**Claude's instruction:** Test that data survives a restart.

```bash
docker compose down
```

**What I saw:**
```
[+] Running 4/4
 ✔ Container api1                        Removed
 ✔ Container redis1                      Removed
 ✔ Container postgres1                   Removed
 ✔ Network sprint-07-compose-v1_default  Removed
```

Network was removed. Containers removed. But volumes NOT removed (by default).

```bash
docker compose up -d
```

The `-d` flag runs in detached mode (background).

**What I saw:**
```
[+] Running 4/4
 ✔ Network sprint-07-compose-v1_default  Created
 ✔ Container redis1                      Started
 ✔ Container postgres1                   Started
 ✔ Container api1                        Started
```

**Health check:**
```bash
curl localhost:8000/health
```

**Result:**
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**Data survived!**

Checked postgres logs:
```bash
docker compose logs postgres | grep "database system"
```

**Result:**
```
postgres1  | 2026-04-11 07:41:22.847 UTC [29] LOG:  database system was shut down at 2026-04-11 07:40:25 UTC
postgres1  | 2026-04-11 07:41:22.852 UTC [1] LOG:  database system is ready to accept connections
```

"database system was shut down" then "ready to accept connections" — the database used existing data, didn't reinitialize.

---

## Testing Volume Destruction

**Claude's instruction:** See what `-v` does.

```bash
docker compose down -v
```

**What I saw:**
```
[+] Running 5/5
 ✔ Container api1                             Removed
 ✔ Container postgres1                        Removed
 ✔ Container redis1                           Removed
 ✔ Volume sprint-07-compose-v1_postgres-data  Removed  ← VOLUME GONE
 ✔ Network sprint-07-compose-v1_default       Removed
```

**The difference:**
- `docker compose down` → stops containers, removes network, **keeps volumes**
- `docker compose down -v` → nuclear option, destroys volumes too

**Restart after volume deletion:**

```bash
docker compose up -d
```

**What I saw:**
```
[+] Running 5/5
 ✔ Network sprint-07-compose-v1_default         Created
 ✔ Volume "sprint-07-compose-v1_postgres-data"  Created  ← NEW VOLUME
 ✔ Container redis1                             Started
 ✔ Container postgres1                          Started
 ✔ Container api1                               Started
```

**Postgres logs:**
```bash
docker compose logs postgres | grep "database system"
```

**Result:**
```
postgres1  | The files belonging to this database system will be owned by user "postgres".
postgres1  | 2026-04-11 07:47:00.927 UTC [44] LOG:  database system was shut down at 2026-04-11 07:47:00 UTC
postgres1  | 2026-04-11 07:47:00.929 UTC [41] LOG:  database system is ready to accept connections
postgres1  | 2026-04-11 07:47:01.092 UTC [41] LOG:  database system is shut down
postgres1  | 2026-04-11 07:47:01.170 UTC [57] LOG:  database system was shut down at 2026-04-11 07:47:01 UTC
postgres1  | 2026-04-11 07:47:01.172 UTC [1] LOG:  database system is ready to accept connections
```

"The files belonging to this database system will be owned by user postgres" — brand new database initialization. The volume was gone, so postgres started from scratch.

**Key insight:** In production, you almost never use `-v`. Data is precious. Only use `-v` when you intentionally want to wipe everything clean.

---

## Phase 3 — The Challenge

**Claude's Challenge:**

Remove the `depends_on:` section from the api service. Save the file. Then:
```bash
docker compose down
docker compose up
```

Watch the startup logs. Does the API start cleanly, or do you see errors? Why?

**No hints for 5 minutes.**

---

**My Exploration:**

I edited docker-compose.yml and removed:
```yaml
depends_on:
  - postgres
  - redis
```

Then restarted:
```bash
docker compose down
docker compose up
```

**What I saw:**

All three services started. Health check was successful:
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**But I noticed in the logs:**
```
redis1     | 1:M 11 Apr 2026 07:51:28.010 * Ready to accept connections tcp
postgres1  | 2026-04-11 07:51:28.910 UTC [1] LOG:  database system is ready to accept connections
api1       | {"timestamp": "2026-04-11T07:51:28.802838+00:00", "level": "INFO", "logger": "app.main", "message": "Running Alembic migrations", ...}
```

**Timing analysis:**
- redis ready: 07:51:28.010
- api started migrations: 07:51:28.802 (108ms after redis)
- postgres ready: 07:51:28.910 (108ms after api started)

**API started BEFORE postgres was ready!**

**Why didn't it fail?** The timing gap was only 108ms. Postgres initialization was fast enough that by the time the API tried to connect, postgres was ready.

**Why this is dangerous:**
- In production with slow disk or cold start, postgres might take 5-10 seconds to initialize.
- API would crash trying to connect before postgres is ready.
- In local dev with fast SSD, you "get lucky" — the race condition doesn't manifest.

**The problem with depends_on:**

`depends_on` only controls **start order**, not **readiness**. It tells Compose "start postgres before api" but doesn't wait for postgres to be healthy and accepting connections.

**Two solutions:**

1. **Health check condition in Compose:**
```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U runmatic"]
    interval: 5s
    timeout: 3s
    retries: 5

api:
  depends_on:
    postgres:
      condition: service_healthy  # ← waits for health check to pass
```

2. **App-level retry logic:** The API already has connection retry logic in the code (SQLAlchemy connection pool with retry on startup). It retries for 30 seconds before giving up.

**Production approach:** Use BOTH. Compose health checks prevent obviously-broken startups. App retries handle network blips and transient failures.

**Claude's feedback:**

Flawless diagnosis. You identified the race condition, explained why it didn't fail locally but would in production, and named both solutions.

---

## Phase 4 — Explanation

**Claude's Question:**

Explain Docker Compose in 3 sentences. Pretend you're explaining it to a support engineer who's been running applications manually with shell scripts and `docker run` commands. Don't look anything up.

**My Answer:**

Compose is not just a shortcut for writing docker commands, it is infrastructure declared as code. It is a versioned, reviewable, shareable file. It understands the relationship between services, dependencies, shared networks and volumes and manages them as units. (This makes it different from using shell scripts to start services — a shell script does not understand the relationship.)

Compose is a declaration of entire infrastructure (services, volumes, networks). Compose automatically creates a network, attaches the services to it, registers each service name as a DNS name.

depends_on is a critical parameter in docker compose that says the order in which the services have to be started.

**Decision tree for using docker compose:**

- Done for the day? → `docker compose down` → volumes survive, data intact
- Something broken, want clean slate? → `docker compose down -v` → everything gone, start fresh
- Changed application code? → `docker compose up --build` → rebuilds image, restarts services
- Changed only config/env vars? → `docker compose up -d` → Compose detects changes, recreates affected containers

**Claude's Feedback:**

Concept: 9/10 — Infrastructure as code. Understands the relationship model (not just command shortcuts). Explained automatic network creation, DNS registration, and the critical depends_on race condition with both solutions. Decision tree shows workflow thinking.

Only gap: I asked for 3 sentences, you gave me a manifesto (but it was a good manifesto).

Execution: 10/10 — Compose file worked first try. Tested persistence. Tested -v flag. Independently observed service vs container name distinction and published vs internal ports. Removed depends_on, diagnosed the race condition.

**Total: 20/20**

---

## Bonus Challenge — Network Isolation

**Claude's Challenge:**

Add a monitoring service to docker-compose.yml:
```yaml
services:
  # ... existing api, postgres, redis ...
  
  monitor:
    image: prom/prometheus:latest
    container_name: monitor1
    ports:
      - "9090:9090"
    networks:
      - monitoring-net

networks:
  monitoring-net:
```

The monitor can't reach the API by name. Error: `dial tcp: lookup api on 127.0.0.11:53: no such host`

What's wrong? Why can't the monitor find the API?

---

**My Investigation:**

I simulated this by modifying my existing compose file. I added explicit network to API only:

```yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: postgres1
    environment:
      POSTGRES_DB: runmatic
      POSTGRES_USER: runmatic
      POSTGRES_PASSWORD: devpassword
    volumes:
      - postgres-data:/var/lib/postgresql/data
    # No networks: declared — joins default automatically
 
  redis:
    image: redis:7-alpine
    container_name: redis1
    # No networks: declared — joins default automatically

  api:
    image: runmatic-api-v1
    container_name: api1
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql+asyncpg://runmatic:devpassword@postgres:5432/runmatic
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: dev-secret-key
    networks:
      - backend  # ← Explicit network

volumes:
  postgres-data:

networks:
  backend:  # ← Custom network declared
```

**Started the stack:**

```bash
docker compose up
```

**What I saw:**
```
[+] Running 6/6
 ✔ Network sprint-07-compose-v1_default         Created
 ✔ Network sprint-07-compose-v1_backend         Created  ← TWO NETWORKS!
 ✔ Volume "sprint-07-compose-v1_postgres-data"  Created
 ✔ Container postgres1                          Created
 ✔ Container redis1                             Created
 ✔ Container api1                               Created
```

Two networks created:
1. `sprint-07-compose-v1_default` — auto-created for services without explicit networks
2. `sprint-07-compose-v1_backend` — the explicit network I declared

**Inspected default network:**

```bash
docker network inspect sprint-07-compose-v1_default
```

**Result:**
- postgres1: 172.23.0.2
- redis1: 172.23.0.3
- **API is NOT on this network**

**Inspected backend network:**

```bash
docker network inspect sprint-07-compose-v1_backend
```

**Result:**
- api1: 172.24.0.2
- **postgres and redis are NOT on this network**

**Health check:**

```bash
curl localhost:8000/health
```

**Result:**
```json
{"status":"degraded","db":"disconnected","cache":"disconnected","details":{"db_error":"[Errno -2] Name or service not known","cache_error":"Error -2 connecting to redis:6379. -2."}}
```

**Diagnosis:**

API is on `backend` network. postgres and redis are on `default` network. They're isolated — can't communicate across network boundaries.

**Root cause:**

When you add `networks:` to ANY service in the compose file, Compose stops auto-assigning that service to the default network. It ONLY joins the networks you explicitly list.

Services without `networks:` still join `default` automatically.

This creates network isolation when you mix explicit and implicit network assignments.

**The fix — two options:**

1. **Remove all explicit networks** — let everything join default:
```yaml
# Delete the networks: section from api
# Delete the networks: top-level section
# All services join sprint-07-compose-v1_default automatically
```

2. **Add the same network to all dependent services:**
```yaml
postgres:
  networks:
    - backend

redis:
  networks:
    - backend

api:
  networks:
    - backend

networks:
  backend:
```

**I chose option 1** for this sprint (removed explicit networks). In Sprint 08 or later, explicit network segmentation will matter (e.g., isolating databases from internet-facing services).

**Bonus Score: 10/10**

- Diagnosis: 5/5 — Root cause identified with `docker network inspect`. Showed both networks with container membership.
- Fix: 5/5 — Stated both valid solutions. Explained the rule about explicit networks.

---

## Key Takeaways

1. **Compose auto-creates a network** — all services without explicit `networks:` join the default network automatically
2. **Service name = DNS hostname** — containers communicate using service names, not container names or IPs
3. **depends_on controls start order only** — does NOT wait for readiness. Use health checks or app retry logic.
4. **docker compose down vs down -v** — down preserves volumes, down -v destroys everything
5. **Mixing explicit and implicit networks creates isolation** — when you add `networks:` to one service, it ONLY joins those networks (not default)
6. **Published ports (-p) are for host access** — containers on same network communicate internally without publishing ports
7. **Container name vs service name** — container name is a label for docker ps, service name is the DNS entry
8. **One file, one command, repeatable infrastructure** — docker-compose.yml is executable documentation
