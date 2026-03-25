# SPRINTS.md — Runmatic Complete Curriculum
*All 32 sprints across 3 acts. Full teaching context for every sprint.*
*Static reference — never modified during learning.*

---

## Curriculum Design Philosophy

Every sprint uses the same application — Runmatic — as the substrate. No toy examples. Every Dockerfile runs real code. Every network carries real traffic. Every volume stores real runbook data. The infrastructure grows in complexity sprint by sprint, mirroring how a real production system evolves from a developer's laptop to a cloud-hosted platform.

**The mental model arc:**
- Act 1: "How do I package and run this thing reliably?" → Containers
- Act 2: "How do I run this reliably at scale across machines?" → Orchestration
- Act 3: "How do I know it's working and never deploy manually again?" → Platform

**Sprint type legend:**
- 🔭 Conceptual — observation and mental model. Produces: README, commands.sh, notes.md, SCORE.md
- 🔨 Build — writes an infrastructure file. Produces: infra file, README, commands.sh, SCORE.md
- 🏁 Capstone — proves act mastery. Produces: all artifacts + extended SCORE.md

---

## ACT 1 — DOCKER (Sprints 01–12)
**Theme:** Containerizing Runmatic from a single process to a full local multi-service stack
**Environment:** Mac local (Docker Desktop)
**Exit condition:** `docker compose up` → all 5 services start, all health checks pass, data persists across restarts
**Duration:** ~6 weeks at 1 sprint/day, 5 days/week

---

### Sprint 01 — Containers & the Docker Mental Model 🔭
**Topic:** What a container is, why it exists, and how it differs from a VM
**Duration:** 35 min
**Sprint type:** Conceptual — no infra file written
**Done condition:** Vela can start, stop, and inspect the Runmatic API container and explain in one sentence why containers exist

**The analogy:**
A VM is a house — its own foundation, walls, plumbing, electricity. Independent but heavy to build.
A container is a shipping container — it shares the ship's infrastructure (the OS kernel) but has completely isolated contents. Docker is the shipping company: it manages loading, tracking, and unloading.

Connect to Vela's background: She's used Autosys to manage jobs on shared servers. Those jobs could interfere — wrong Python version, conflicting libraries, a job that fills up disk space. A container is the solution to that problem. Each process gets its own isolated world on the same physical host, with its own filesystem, its own network stack, its own process tree.

**What Vela does:**
1. `docker pull` the Runmatic API image
2. `docker run -p 8000:8000 runmatic-api` — observe startup logs
3. `docker ps` — observe running container, container ID, ports, uptime
4. `curl localhost:8000/health` — confirm the API responds
5. `docker stop [id]` then `docker start [id]` — observe lifecycle
6. `docker rm [id]` — remove it
7. `docker logs [id]` — read logs after the fact
8. `docker inspect [id]` — explore the metadata JSON: IP, mounts, environment, state

**Key concepts:**
- Container vs VM (kernel sharing vs full OS per guest)
- Docker daemon, Docker CLI, Docker Hub
- Container lifecycle: created → running → stopped → removed
- The process model: container = process, stop the container = kill the process
- Port mapping: why `-p 8000:8000` is needed (container network is isolated from host)
- The difference between an image and a container (image = recipe, container = running meal)

**Common mistakes to surface:**
- Forgetting `-p` and wondering why the API isn't reachable
- Stopping a container and assuming data is lost (it isn't until `rm`)
- Confusing image and container concepts

**Break-fix bonus (if 16+/20):**
The API container shows as running in `docker ps` but `curl localhost:8000/health` returns "connection refused." What's wrong? (Answer: missing -p port mapping — container port is not published to host)

**Connection to Sprint 02:** "You ran a container from an image someone else built. Next sprint you'll look inside that image and understand exactly what it contains and why."

---

### Sprint 02 — Images & Layers 🔭
**Topic:** What a Docker image is, how layers work, and how to read what's inside one
**Duration:** 35 min
**Sprint type:** Conceptual — no infra file written
**Done condition:** Vela can explain what a Docker layer is, why they're cached, and identify the application layer in Runmatic's image from `docker image history`

**The analogy:**
An image is a stack of transparencies (overhead projector sheets). Each sheet adds something on top of the previous one — the base OS, then the Python runtime, then the dependencies, then the application code. Stack them all and you see the complete filesystem. Docker builds images this way. The magic: if two images share the same base layer (both use `python:3.11-slim`), Docker only stores that layer once on disk. Pulling a second Python image is instant — the layer is already there.

**What Vela does:**
1. `docker image ls` — see all images on the machine
2. `docker pull python:3.11-slim` — watch layers download one by one
3. `docker pull python:3.11-slim` again — observe "Already exists" for every layer
4. `docker image history runmatic-api` — see every layer, its size, and the instruction that created it
5. `docker image inspect runmatic-api` — explore the full metadata JSON
6. `docker save runmatic-api | tar -tv | head -30` — actually look inside an image as a tar archive
7. Identify: which layer is the OS? Which is the Python install? Which is the app code?

**Key concepts:**
- Union filesystem (OverlayFS) — layers stack to form a single coherent filesystem view
- Layer caching — unchanged layers are reused, changed layers and everything after them rebuild
- Read-only layers (image) + read-write layer (running container) = what you see inside a container
- Image tags vs digests — tags are mutable, digests are immutable
- Image size vs disk usage — shared layers mean total disk use is less than sum of image sizes

**Common mistakes to surface:**
- Confusing image size (shown in `docker images`) with actual disk usage (layers are shared)
- Not understanding why changing a base layer invalidates all subsequent cached layers
- Thinking `docker pull` always downloads everything (it only downloads missing layers)

**Break-fix bonus (if 16+/20):**
`python:3.11-slim` is 130MB. `runmatic-api` (based on it) is 320MB. `docker images` shows 130 + 320 = 450MB total. But `du -sh ~/.docker` shows only ~380MB used. Where did 70MB go?

**Connection to Sprint 03:** "You can read an image and understand its layers. Next sprint you'll write the instructions that create those layers — from scratch."

---

### Sprint 03 — Writing Dockerfiles 🔨
**Topic:** The Dockerfile instruction set. Writing a production-quality Dockerfile for Runmatic's API.
**Duration:** 35 min
**Sprint type:** Build — writes `Dockerfile.api`
**Done condition:** `docker build` succeeds. `docker run` starts the container. `curl localhost:8000/health` returns `{"status":"healthy"}`.

**The analogy:**
As a support engineer, you've provisioned servers manually: log in, install Python, install packages, copy the app, configure the start command. A Dockerfile captures that exact process as code. The difference: it runs identically on any machine, any time, for any engineer on the team. No more "it works on my machine" — because the machine is defined in the file.

Connect to Vela's background: Every manual server setup she's done was undocumented, unrepeatable, and lived only in one person's memory. A Dockerfile is that process, versioned in git, reproducible forever.

**What Vela does:**
1. Read `app/api/requirements.txt` — understand the dependency list
2. Read `app/api/main.py` (first 20 lines) — find the entry point and start command
3. Write `infra/docker/sprint-03-dockerfiles/Dockerfile.api` from scratch
4. `docker build -t runmatic-api-v1 -f infra/docker/sprint-03-dockerfiles/Dockerfile.api .`
5. Debug any build failures
6. `docker run -d -p 8000:8000 --name api-test runmatic-api-v1`
7. `curl localhost:8000/health`
8. `docker image history runmatic-api-v1` — see the layers she created
9. Change one line in app/api code — observe rebuild time (baseline for Sprint 10)

**Scaffold provided in chat (not written by Claude to disk):**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
# TODO(vela): copy requirements first — why before the code?
# TODO(vela): install dependencies
# TODO(vela): copy application code
EXPOSE 8000
# TODO(vela): start command — which form? why?
```

**Key concepts:**
- FROM — base image selection, why slim/alpine matters (size, attack surface)
- WORKDIR — why you always set it (avoids files landing in /)
- COPY — build context, what gets copied, `.dockerignore`
- RUN — runs at build time, creates a layer, not available at runtime
- EXPOSE — documentation only, does not publish ports
- CMD exec form `["uvicorn", "..."]` vs shell form `uvicorn ...` — signal handling (SIGTERM)
- Layer order and caching — COPY requirements before COPY code

**Common mistakes to surface:**
- Copying everything before installing dependencies (breaks layer caching)
- Using shell form CMD (wraps in /bin/sh, swallows SIGTERM — critical for Sprint 11)
- Not using `--no-cache-dir` with pip (larger images)
- Forgetting .dockerignore — copying `__pycache__`, `.env`, `node_modules`

**Break-fix bonus (if 16+/20):**
First build: 94 seconds. You change a comment in `main.py` and rebuild: still 94 seconds. All layers rebuild. Why? Show exactly how to fix the Dockerfile so changing `main.py` takes < 10 seconds to rebuild.

**Connection to Sprint 04:** "Your Dockerfile works but the database URL is hardcoded in it. If you push this image to Docker Hub, the database password is public. Next sprint we fix that."

---

### Sprint 04 — Environment & Configuration 🔨
**Topic:** Managing runtime configuration through environment variables. The 12-Factor App config principle.
**Duration:** 35 min
**Sprint type:** Build — refactors Dockerfile, writes `.env.example`
**Done condition:** API container runs with all config injected via env vars. No hardcoded values in the Dockerfile. `.env.example` documents all required variables.

**The analogy:**
Imagine a Dockerfile with `DATABASE_URL=postgresql://prod-server:5432/runmatic` baked into it. You want to test locally. You'd need to rebuild the image just to change the database address. That's absurd. Environment variables are the knobs on the outside of a black box. The container (the box) is fixed and portable. The environment (which database, which Redis, which secret key) is injected at runtime. Same image, different knobs, different environments.

**The 12-Factor principle:** Config that changes between deployments (dev/staging/prod) must come from the environment, never from code or the image.

**What Vela does:**
1. Identify every hardcoded value in the existing Dockerfile (DATABASE_URL, SECRET_KEY, etc.)
2. Update `Dockerfile.api` to use `ENV` with sensible defaults
3. `docker run -e DATABASE_URL=... -e SECRET_KEY=... runmatic-api-v1` — inject at runtime
4. Create `.env.example` (not `.env` — the actual secret file is gitignored)
5. `docker run --env-file .env.example runmatic-api-v1` — use the file
6. Verify via `curl localhost:8000/health` that config is being read
7. Check startup logs to confirm env vars are loaded
8. `docker inspect [container] | grep Env` — observe env vars visible in inspect

**Key concepts:**
- ENV (runtime, persists in image) vs ARG (build-time only, not in final image)
- `--env-file` for passing multiple vars from a file
- Why `.env` must be in `.gitignore` — secrets in git history are permanent
- Why ENV values in Dockerfile are visible in `docker inspect` — don't put secrets there
- `.env.example` pattern — commit the template, never the secrets
- The 12-Factor App config principle (https://12factor.net/config)

**Connect to Vela's background:** She's handled incident tickets from apps that leaked credentials. This is the Dockerfile equivalent — a misconfigured image is a credential leak waiting to happen.

**Connection to Sprint 05:** "Config is clean. But if you stop the container, all database data is gone. The runbooks Vela just created? Gone. Next sprint we fix that."

---

### Sprint 05 — Volumes & Persistence 🔨
**Topic:** How Docker volumes work. Why stateful services need them. Named volumes vs bind mounts.
**Duration:** 35 min
**Sprint type:** Build — writes docker run commands with volume mounts, documents volume strategy
**Done condition:** PostgreSQL container with named volume. Insert runbook data. Stop and remove container. Create new container with same volume. Data is still there.

**The analogy:**
A container's filesystem is like RAM — fast, isolated, and completely gone when the process dies. A named volume is like an external hard drive you plug into the container. The container can read and write to it. When you remove the container and create a new one, you plug in the same hard drive. All the data is still there.

Connect to Vela's background: She's managed PostgreSQL databases in production. She knows data must survive restarts. A PostgreSQL container without a volume is a database that loses every runbook, every incident record, every action item on every container restart. That's not a database — it's a very expensive in-memory cache.

**What Vela does:**
1. Run PostgreSQL WITHOUT a volume — insert data via psql, stop and remove container, observe data gone
2. `docker volume create runmatic-postgres-data`
3. Run PostgreSQL WITH the volume mounted at `/var/lib/postgresql/data`
4. Insert runbook data
5. `docker stop` and `docker rm` the container
6. Create a brand new PostgreSQL container with the same volume
7. Connect and verify all data is still present
8. `docker volume inspect runmatic-postgres-data` — see host path where data lives
9. `docker volume ls` — list all volumes
10. Understand the difference between named volumes (Docker manages) and bind mounts (you specify host path)

**Key concepts:**
- Container filesystem lifecycle — ephemeral by default, intentionally
- Named volumes vs bind mounts — when to use each
- Why bind mounts have permission issues with databases
- Where Docker Desktop stores named volume data on Mac (inside the Linux VM)
- `docker volume prune` — danger of cleaning up volumes with live data
- Why the mount path must match what the service expects (`/var/lib/postgresql/data`)

**Break-fix bonus (if 16+/20):**
PostgreSQL container starts, volume is mounted, but the DB reports it can't write to `/var/lib/postgresql/data` — permission denied. The volume is mounted correctly. What's wrong and why?

**Connection to Sprint 06:** "Data persists. But to connect the API to the database, you've been using the container's internal IP address — which changes every restart. Next sprint we fix that with networking."

---

### Sprint 06 — Container Networking 🔨
**Topic:** Docker network types, container DNS, and how services find each other by name
**Duration:** 35 min
**Sprint type:** Build — creates custom bridge network, runs API + postgres communicating by name
**Done condition:** API container connects to PostgreSQL using hostname `postgres`, not an IP. `curl localhost:8000/health` shows `"db": "connected"`.

**The analogy:**
Containers on the same Docker network are like computers on an office LAN. They each have a hostname (their container name) and an IP address. Docker runs a tiny internal DNS server — when the API container says "connect to postgres", Docker's DNS resolves "postgres" to whichever IP that container currently has. No hardcoded IPs. The name is stable. The IP is not.

This is why `DATABASE_URL=postgresql://postgres:5432/runmatic` works. Not `postgresql://172.17.0.3:5432/runmatic`. Because tomorrow that container might be `172.17.0.4`.

Connect to Vela's background: She's familiar with DNS from networking basics and Splunk's service discovery. Same concept — names instead of IPs, a resolver in the middle.

**What Vela does:**
1. Try to connect two containers on the default bridge network — observe DNS doesn't work
2. `docker network create runmatic-net`
3. Run PostgreSQL with `--network runmatic-net --name postgres`
4. Run API with `--network runmatic-net --name api` and `DATABASE_URL=postgresql://postgres:5432/runmatic`
5. `curl localhost:8000/health` — observe db: connected
6. `docker network inspect runmatic-net` — see both containers, their IPs, their names
7. `docker exec -it api ping postgres` — DNS resolution works
8. Stop postgres, start a new postgres container on the same network — same name, different IP, API reconnects

**Key concepts:**
- Default bridge network (no DNS, only IP communication) vs custom bridge network (DNS enabled)
- Container DNS resolution — how Docker's embedded DNS maps container names to IPs
- Network isolation — containers on different networks can't reach each other
- `--network` and `--name` flags working together to enable DNS
- Published ports (for host access) vs network ports (for container-to-container)
- Why you almost never use the default bridge network in real applications

**Connection to Sprint 07:** "Two containers communicating. But that's two separate `docker run` commands with 15 flags each — unwieldy, error-prone, and doesn't scale. Next sprint: one file, one command."

---

### Sprint 07 — Docker Compose v1 🔨
**Topic:** Docker Compose — defining and running multi-container applications as code
**Duration:** 35 min
**Sprint type:** Build — writes docker-compose.yml (API + PostgreSQL)
**Done condition:** `docker compose up` brings up API and PostgreSQL. API connects to postgres. Data persists across `compose down` and `compose up`. `docker compose logs api` shows clean startup.

**The analogy:**
You've been running containers manually — two terminal windows, two `docker run` commands with 15 flags each, remembered in the right order. Docker Compose is the conductor. You describe the entire orchestra in one YAML file: here are my musicians (services), here's their equipment (volumes), here's the stage layout (networks). One command: `docker compose up`. The conductor handles the rest.

Connect to Vela's background: She's used Autosys to define job chains — dependencies, sequences, environments. Compose is Autosys for containers. Define the graph, let the tool figure out the order.

**What Vela does:**
1. Write `infra/docker/sprint-07-compose-v1/docker-compose.yml` from scratch
2. Define `api` service (image, ports, environment, depends_on)
3. Define `postgres` service (image, environment, volume mount)
4. Define named volume for postgres data
5. `docker compose up` — observe ordered startup in combined log output
6. `docker compose ps` — service status table
7. `docker compose logs api` — per-service log access
8. Create a runbook via the API, `docker compose down`, `docker compose up`, verify runbook still exists
9. `docker compose down -v` — understand what this destroys (and when you'd use it)

**Scaffold provided in chat:**
```yaml
services:
  api:
    # TODO(vela): image, ports, environment, depends_on

  postgres:
    # TODO(vela): image, environment, volume mount

volumes:
  # TODO(vela): declare the named volume

networks:
  # TODO(vela): Compose creates a default network — do we need to declare it?
```

**Key concepts:**
- Compose file structure: services, volumes, networks
- `depends_on` — starts after, not waits for ready (critical distinction)
- Compose automatic networking — service names become DNS hostnames automatically
- `docker compose up -d` (detached mode) vs foreground
- `docker compose down` vs `docker compose down -v` — what gets deleted
- Compose project naming and container naming conventions

**Common mistakes to surface:**
- `depends_on` doesn't wait for postgres to accept connections — just for the process to start
- Forgetting to persist the volume — Compose creates anonymous volumes that vanish on `down`
- Port conflicts if containers from previous sprints are still running

**Connection to Sprint 08:** "API + postgres in one file. Runmatic also needs Redis and a background worker. Next sprint: 4 services, health checks, proper startup ordering."

---

### Sprint 08 — Docker Compose v2 🔨
**Topic:** Multi-service Compose with health checks and conditional startup ordering
**Duration:** 35 min
**Sprint type:** Build — extends docker-compose.yml with Redis, Worker, and health checks
**Done condition:** All 4 services running. Health checks configured. API only starts after postgres is confirmed healthy. Worker only starts after both postgres and redis are healthy.

**The analogy:**
`depends_on` is a polite request: "Please start postgres before the API." But postgres takes 3–5 seconds after its process starts before it's ready to accept connections. During that window, the API tries to connect and fails.

`depends_on` with `condition: service_healthy` is a contract enforced by a health check: "Don't start the API until postgres has passed its health check — actually ready, not just running." The difference between "process started" and "service ready" is what separates a flaky system from a reliable one.

Connect to Vela's background: She's been the on-call engineer who restarts services in the right order during an incident. Health checks automate exactly that judgment.

**What Vela does:**
1. Add `redis` service to docker-compose.yml
2. Add `worker` service (no ports — internal only)
3. Add health check to `postgres`: `pg_isready -U runmatic -d runmatic`
4. Add health check to `redis`: `redis-cli ping`
5. Update `api` depends_on: `postgres: condition: service_healthy`
6. Update `worker` depends_on: both postgres and redis healthy
7. `docker compose up` — watch health check polling in log output
8. `docker compose ps` — observe "healthy" vs "starting" status
9. Deliberately break the postgres health check — observe API waiting indefinitely
10. Fix it, observe recovery

**Key concepts:**
- Health check anatomy: `test`, `interval`, `timeout`, `retries`, `start_period`
- `condition: service_healthy` vs `condition: service_started` vs `condition: service_completed_successfully`
- Why `start_period` matters for databases (initial setup takes longer than steady-state)
- Worker as a consumer-only service — no published ports, internal to the network
- Resource limits in Compose (preview — will matter in K8s resource requests)

**Break-fix bonus (if 16+/20):**
All 4 services start. `docker compose ps` shows all healthy. But the API's /health endpoint returns `{"status": "healthy", "db": "connected", "cache": "disconnected"}`. Redis is clearly running. What's wrong?

**Connection to Sprint 09:** "Backend is solid. But Runmatic has a frontend. Next sprint: containerize the React UI and add it to Compose."

---

### Sprint 09 — Frontend Container 🔨
**Topic:** Containerizing a React frontend with Nginx, proxying API traffic
**Duration:** 35 min
**Sprint type:** Build — writes Dockerfile.frontend, updates docker-compose.yml
**Done condition:** Browser at localhost:3000 shows Runmatic UI. Creating a runbook via the UI stores it in the database. `docker compose logs frontend` shows Nginx access logs.

**The analogy:**
The frontend is a two-stage process. Stage 1 (build time): the React app is compiled from TypeScript into static HTML/CSS/JS files — just a folder of files. Stage 2 (runtime): Nginx serves those files to browsers.

But there's a catch: the browser needs to talk to the API. The browser is outside Docker — it can't use Docker DNS to reach the `api` container by name. Nginx is the bridge: it runs inside Docker, knows Docker DNS, and proxies `/api/*` requests from the browser to `http://api:8000`. The browser talks to one address; Nginx routes it.

**What Vela does:**
1. Read `app/frontend/nginx.conf` — understand the proxy_pass configuration
2. Write `infra/docker/sprint-09-frontend/Dockerfile.frontend`
3. Update `docker-compose.yml` to add the frontend service
4. `docker compose up` — open browser at localhost:3000
5. Create a runbook via the UI
6. Verify it appears after page refresh (data is in the database)
7. `docker compose logs frontend` — observe Nginx access logs for both static file serves and API proxies

**Key concepts:**
- Static asset serving — compiled React is just files, served by Nginx
- Nginx as a reverse proxy — why the frontend container needs it
- The browser's network context vs Docker's network context (why browser can't use Docker DNS)
- How `proxy_pass http://api:8000` works from inside Docker
- Build context and Dockerfile path — `docker build` context must include the right files

**Note for Sprint 10 preview:** This Dockerfile builds the frontend inside a single large image. Sprint 10 introduces multi-stage builds to fix this.

---

### Sprint 10 — Multi-Stage Builds & Image Optimization 🔨
**Topic:** Multi-stage Dockerfiles, image size reduction, production-grade images
**Duration:** 35 min
**Sprint type:** Build — rewrites Dockerfiles for API and frontend as multi-stage
**Done condition:** API image reduced by at least 50%. Frontend image reduced by at least 60%. Both services still function correctly.

**The analogy:**
Building a ship in a shipyard requires cranes, welding equipment, scaffolding — massive infrastructure. None of that goes on the ship when it sails. A multi-stage build is the same: Stage 1 is the shipyard (all build tools, compilers, dev dependencies). Stage 2 is the ship (only what's needed to run). The final image contains only Stage 2. Everything from Stage 1 is discarded.

For the frontend: Stage 1 installs Node.js (600MB), all npm packages, and compiles TypeScript into static files. Stage 2 is Nginx (30MB) plus just the compiled files. The Node.js runtime — no longer needed — is completely gone from the final image.

**What Vela does:**
1. `docker image ls` — record baseline sizes for api and frontend images
2. Rewrite `Dockerfile.api` as multi-stage: `builder` (pip install) → `runtime` (just the app)
3. Rewrite `Dockerfile.frontend` as multi-stage: `builder` (npm build) → `runtime` (nginx + dist/)
4. Build both and compare sizes
5. `docker image history runmatic-api-v2` — observe fewer layers in final image
6. Verify both services still work in Compose
7. Calculate the percentage reduction for SCORE.md

**Key concepts:**
- Multi-stage build syntax: `FROM ... AS builder`, `COPY --from=builder`
- What to include in builder stage vs runtime stage
- `--no-cache-dir` for pip, `npm ci` vs `npm install`
- Why production images should never contain test dependencies, build tools, or docs
- Alpine vs slim base images — size vs compatibility tradeoffs
- Image vulnerability scanning preview (`docker scout`)

**Break-fix bonus (if 16+/20):**
After converting to multi-stage, the frontend image is 85% smaller. But Nginx fails to start: "open() '/etc/nginx/nginx.conf' failed (2: No such file or directory)." The nginx.conf exists in the repo. What's wrong?

---

### Sprint 11 — Health Checks, Restart Policies & Graceful Shutdown 🔨
**Topic:** Making Runmatic self-healing. Production operational patterns.
**Duration:** 35 min
**Sprint type:** Build — updates docker-compose.yml with restart policies, adds SIGTERM handling
**Done condition:** Killing any single service results in automatic restart. API logs show clean "shutdown complete" message on SIGTERM. All services have restart policies.

**The analogy:**
A restart policy is automation for the "restart the service" runbook entry Vela has probably executed hundreds of times during on-call shifts. Instead of being paged at 2am because the API crashed, the policy restarts it in seconds automatically. SIGTERM is the polite ask — "please stop." SIGKILL is the forced kill — "stop now, no cleanup." Graceful shutdown means the service finishes in-flight requests before stopping. Without it, users get errors mid-request.

Connect to Vela's background: She's been paged for service crashes. Restart policies eliminate entire categories of incidents. Graceful shutdown prevents data corruption during deployments.

**What Vela does:**
1. Add `restart: unless-stopped` to all services in docker-compose.yml
2. `docker compose up`, then `docker compose kill api` — observe automatic restart
3. Verify API has exec form CMD (from Sprint 03 lesson) — prerequisite for signal handling
4. `docker compose stop api` — observe graceful shutdown in logs
5. `docker compose kill api` — observe abrupt termination (no shutdown log)
6. Add `stop_grace_period: 30s` to postgres — why databases need time to flush
7. Add a proper health check to the API itself (HTTP check on /health endpoint)
8. Observe full startup sequence: postgres healthy → redis healthy → api starts → api healthy → worker starts

**Key concepts:**
- Restart policies: `no`, `always`, `on-failure`, `unless-stopped` — when to use each
- SIGTERM (graceful request) vs SIGKILL (forced termination) — why the difference matters
- PID 1 problem — why shell form CMD breaks signal handling (`/bin/sh` doesn't forward signals)
- `stop_grace_period` — why databases, workers, and message consumers need longer shutdown time
- Health check failure (container stays running, marked unhealthy) vs container crash (restart triggered)

---

### Sprint 12 — Act 1 Capstone 🏁
**Topic:** Integration, documentation, and proving Docker mastery
**Duration:** 35 min (may extend — this is the capstone)
**Sprint type:** Capstone
**Done condition:** Runmatic runs end-to-end. Vela can explain the full Docker infrastructure, every decision, and every file.

**What this sprint is:**
Not new content. This is a proof of mastery session. Vela demonstrates she can operate Runmatic's full Docker infrastructure, explain every architectural decision, and document the complete system.

**Vela must demonstrate:**
1. `docker compose up` → all 5 services start, all health checks pass (within 60 seconds)
2. Create a runbook via the browser UI
3. `docker compose down && docker compose up` → runbook still exists (volume persistence working)
4. Kill the API container (`docker compose kill api`) → observe automatic restart
5. Explain the network topology: which services talk to which, on what network, using what hostnames
6. Explain the volume strategy: what's persisted, what's ephemeral, why each decision was made
7. Explain why the Dockerfile instruction order matters for build performance
8. Walk through the startup dependency chain from scratch

**Capstone scoring (out of 30):**
- Architecture explanation (10): Can she explain the complete system accurately to a stranger?
- Operational proof (10): Does everything work correctly end-to-end?
- Documentation quality (10): Are all sprint folders complete with README, commands.sh, SCORE.md?

**Act 1 unlock condition:** Score 24+/30. If below 24, identify the weakest sprint and redo it before Act 2.

**After passing:** Claude updates PROGRESS.md: `ACT_1_COMPLETE: true`, `CURRENT_ACT: 2`. Claude updates CHANGELOG.md with Act 1 completion entry.

---

## ACT 2 — KUBERNETES (Sprints 13–20)
**Theme:** Moving Runmatic from Docker Compose to Kubernetes — same app, radically different substrate
**Prerequisite:** Act 1 capstone passed (24+/30)
**Environment:** Local K8s (K3s via Rancher Desktop, or minikube)
**Exit condition:** Full Runmatic stack running on local K8s, self-healing, accessible via Ingress, worker scales under load
**Duration:** ~4 weeks

**The mental model shift — state this explicitly at Act 2 start:**
Docker Compose: "Here are my containers. Run them on this machine."
Kubernetes: "Here is my desired state. Make reality match it, on however many machines you have, and keep it that way forever — even when things fail."

Kubernetes doesn't run containers — it manages desired state. You declare what you want. The control plane figures out how to make it happen and maintains it continuously.

---

### Sprint 13 — Kubernetes Mental Model 🔭
**Topic:** Control plane architecture, nodes, pods — understanding K8s before writing a single YAML
**Duration:** 35 min
**Sprint type:** Conceptual
**Done condition:** K3s/minikube running locally. `kubectl get nodes` shows a ready node. Vela can label all control plane components from memory and explain what each one does.

**The analogy:**
Kubernetes is a robot facility manager. You write a note: "I want 3 copies of the API running at all times." The manager reads the note, starts the processes, watches them, restarts any that die, and redistributes them if a machine fails. You don't manage individual processes. You manage intentions.

The control plane is the manager's brain: API server (receives orders), etcd (the notebook where desired state is written — think git for cluster state), scheduler (decides which node runs which pod), controllers (background workers that keep making reality match the notebook).

Connect to Vela's background: She's familiar with Autosys's master/agent model — central brain, distributed executors. Same pattern. Different scale.

**What Vela does:**
1. Install K3s via Rancher Desktop (or minikube)
2. `kubectl get nodes` — observe node(s)
3. `kubectl get pods -A` — see all system pods including control plane components
4. `kubectl get namespaces` — understand namespace isolation
5. `kubectl cluster-info` — control plane endpoint
6. `kubectl describe node [node-name]` — understand node resources, conditions, and events
7. Draw the K8s architecture on paper or whiteboard

**Key concepts:**
- Control plane vs worker nodes
- API server (the single entry point for all cluster operations)
- etcd (distributed key-value store for all cluster state)
- Scheduler (places pods on nodes based on resource requirements)
- Controller manager (runs controllers that reconcile desired vs actual state)
- kubelet (the node agent that runs and monitors pods)
- The reconciliation loop — Kubernetes constantly asks "is reality matching the spec?"

**Connection to Sprint 14:** "You understand the brain. Now let's run the first Runmatic service on it."

---

### Sprint 14 — Pods & Deployments 🔨
**Topic:** The Pod as atomic unit. Deployments as declarative desired state.
**Duration:** 35 min
**Sprint type:** Build — writes api-deployment.yaml
**Done condition:** Runmatic API running as a K8s Deployment with 2 replicas. Deleting one pod results in immediate automatic replacement.

**The analogy:**
A Pod is the smallest thing K8s runs — one or more containers with shared network and storage. But you almost never create a Pod directly, because a standalone Pod that crashes is just gone.

A Deployment is the upgrade: "I want 2 replicas of this Pod, always." The Deployment controller watches constantly. Pod dies? New one created. Node fails? Pods rescheduled. You update the image? Rolling update, zero downtime.

Connect to Vela's Autosys background: A job definition in Autosys tells the system what to run and how to handle failures. A Deployment is that concept applied to containers — declarative, not imperative.

**What Vela does:**
1. Write `infra/k8s/sprint-14-deployments/api-deployment.yaml`
2. `kubectl apply -f api-deployment.yaml`
3. `kubectl get pods` — observe 2 API pods
4. `kubectl describe deployment runmatic-api` — understand status, replicas, conditions
5. `kubectl delete pod [api-pod-name]` — observe immediate replacement (within seconds)
6. `kubectl set image deployment/runmatic-api api=runmatic-api:v2` — observe rolling update
7. `kubectl rollout history deployment/runmatic-api` — see revision history
8. `kubectl rollout undo deployment/runmatic-api` — rollback

**Key concepts:**
- Pod spec vs Deployment spec — the pod template inside a deployment
- ReplicaSet — what Deployments actually create and manage
- Rolling update strategy — maxSurge, maxUnavailable
- Resource requests vs limits (preview — mandatory for HPA in Sprint 19)
- Pod labels and selectors — how Deployments know which pods they own
- `kubectl apply` (declarative) vs `kubectl create` (imperative) — always use apply

---

### Sprint 15 — Services & DNS 🔨
**Topic:** How K8s Services provide stable endpoints and enable inter-service DNS
**Duration:** 35 min
**Sprint type:** Build — writes api-service.yaml and postgres-service.yaml
**Done condition:** API pods reachable via ClusterIP Service. API can connect to PostgreSQL using the Service DNS name.

**The analogy:**
Pods are ephemeral — they die and get replaced with new IPs constantly. A Service is a stable virtual IP and DNS name in front of a group of pods. When the API calls `postgresql://postgres-service:5432`, K8s DNS resolves the name to the Service's ClusterIP, which load-balances to whichever postgres pod is running. Pods come and go. The Service is permanent.

Service types explained in Runmatic context: ClusterIP (API talking to postgres — internal only), NodePort (accessing the API from your laptop during development), LoadBalancer (production access from the internet — Sprint 18 uses Ingress instead).

---

### Sprint 16 — ConfigMaps & Secrets 🔨
**Topic:** Managing configuration and sensitive data as K8s first-class objects
**Duration:** 35 min
**Sprint type:** Build — writes configmap.yaml and secret.yaml for all services
**Done condition:** All Runmatic configuration in ConfigMaps. All sensitive values in Secrets. No environment variables hardcoded in any YAML file.

**The analogy:**
In Compose, you had `.env` files. In K8s, you have two purpose-built objects: ConfigMap (for non-sensitive config — hostnames, feature flags, log levels) and Secret (for sensitive data — passwords, API keys, certificates). Both are separate from the Pod spec, which means you can update config without rebuilding or redeploying.

**Critical security concept:** K8s Secrets are base64-encoded, NOT encrypted. Anyone with kubectl access to the namespace can read them. For real production: use AWS Secrets Manager, Vault, or Sealed Secrets. Understanding this is what separates junior from senior K8s engineers. Document this nuance in the README.

---

### Sprint 17 — Persistent Volumes & PVCs 🔨
**Topic:** Storage in K8s — PersistentVolumes, PersistentVolumeClaims, StatefulSets
**Duration:** 35 min
**Sprint type:** Build — writes postgres-statefulset.yaml with PVC
**Done condition:** PostgreSQL running as a StatefulSet with a PVC. Deleting and recreating the pod — all runbook data survives.

**The analogy:**
In Docker, volumes were simple — a named volume mapped to a path on one machine. In K8s, pods can run on any node in the cluster. A PersistentVolume is a piece of storage that exists in the cluster (like a network-attached drive). A PersistentVolumeClaim is a pod's request: "I need 10GB, any available storage." The cluster matches the claim to a volume.

StatefulSets vs Deployments: PostgreSQL needs a StatefulSet because it needs a stable network identity and stable storage. A Deployment creates pods with random names (runmatic-api-abc123). A StatefulSet creates pods with predictable names (runmatic-postgres-0). For databases, identity matters.

---

### Sprint 18 — Ingress 🔨
**Topic:** Exposing Runmatic to the outside world via Ingress controller
**Duration:** 35 min
**Sprint type:** Build — writes ingress.yaml, configures nginx ingress controller
**Done condition:** Runmatic UI accessible at `runmatic.local` in the browser. API accessible at `runmatic.local/api`.

**The analogy:**
NodePort is hacky — a random high port on every node. LoadBalancer requires a cloud provider. Ingress is the right answer: one entry point (the Ingress controller) that routes HTTP/HTTPS traffic to different Services based on hostname and path rules. One IP, many services. The Ingress resource is the routing rules; the controller is the actual reverse proxy that reads those rules.

This is Nginx in Docker (Sprint 09) elevated to the cluster level — same concept, different scope.

---

### Sprint 19 — Horizontal Pod Autoscaler 🔨
**Topic:** Auto-scaling pods based on CPU/memory metrics
**Duration:** 35 min
**Sprint type:** Build — writes hpa.yaml for the worker service
**Done condition:** Worker scales from 1 to 3 replicas under synthetic load. Scales back to 1 after load subsides.

**The analogy:**
HPA is a feedback loop — a PID controller for your service. Every 15 seconds: "Is CPU utilization across worker pods above 70%? Add a replica. Below 30% for 5 minutes? Remove a replica." This is the difference between "I manually provision extra servers before Black Friday" and "the cluster handles it automatically."

Prerequisites: resource requests must be set on the worker pod (Sprint 14 preview). HPA calculates percentages relative to requests — without them, it has no baseline and can't function.

---

### Sprint 20 — Act 2 Capstone 🏁
**Topic:** Full Runmatic on K8s — proving orchestration mastery
**Duration:** 35 min (may extend)
**Sprint type:** Capstone

**Vela must demonstrate:**
1. All services running as K8s objects (Deployment or StatefulSet)
2. Delete a pod — it's replaced automatically
3. Access Runmatic at runmatic.local — UI loads, API works
4. Scale the worker manually (`kubectl scale`) and via HPA under load
5. Show ConfigMaps and Secrets being consumed by pods
6. Explain the difference between Deployment and StatefulSet in Runmatic context
7. Explain why postgres needs a PVC and what happens without one

**Capstone scoring (out of 30):**
- Architecture explanation (10): K8s concepts explained in Runmatic context
- Operational proof (10): System self-heals and scales correctly
- YAML quality (10): Manifests are clean, commented, and follow best practices

**Act 2 unlock condition:** Score 24+/30. Act 3 unlocks.

---

## ACT 3 — PLATFORM (Sprints 21–32)
**Theme:** Making Runmatic production-grade — automated, observable, cloud-hosted
**Prerequisite:** Act 2 capstone passed (24+/30)
**Environment:** Cloud (AWS) + local for development
**Exit condition:** Runmatic live on AWS EKS, deployed automatically via CI/CD, monitored with Prometheus/Grafana, logs in Loki
**Duration:** ~6 weeks

---

### Sprint 21 — GitHub Actions CI 🔨
**Topic:** Continuous Integration — automated testing and validation on every pull request
**Duration:** 35 min
**Sprint type:** Build — writes .github/workflows/ci.yml
**Done condition:** PR opened against main → GitHub Actions runs lint (flake8), tests (pytest), and Docker build. Status reported on the PR. Failed check blocks merge.

**The analogy:**
CI is a robot code reviewer that never sleeps, never forgets a step, and runs in the same environment every time. Every PR gets the same checks a senior engineer would do manually: does the code pass linting? Do the tests pass? Does the image build? Before CI, "it works on my machine" was a valid excuse. After CI, the pipeline is the arbiter of truth.

Connect to Vela's background: She's seen manual testing checklists before deployments — a list of checks someone runs (or forgets to run) before pushing to production. CI automates that checklist and enforces it on every change.

**Key concepts:**
- Workflow triggers: `push`, `pull_request`, branch filters
- Jobs and steps — the CI pipeline structure
- GitHub Actions runners — where the code actually runs
- Caching dependencies for faster runs (pip cache, Docker layer cache)
- Job status checks and branch protection rules

---

### Sprint 22 — GitHub Actions CD 🔨
**Topic:** Continuous Deployment — automatic image builds and registry pushes on merge
**Duration:** 35 min
**Sprint type:** Build — extends CI workflow with CD job
**Done condition:** Merge to main → GitHub Actions builds all Runmatic images, tags with git SHA, pushes to GitHub Container Registry (ghcr.io). Images visible in the GitHub packages page.

**Key concepts:**
- Git SHA tagging vs `latest` tag — why SHA is safer for deployments
- Registry authentication in GitHub Actions (GITHUB_TOKEN)
- Docker buildx for multi-platform builds (amd64 for AWS, arm64 for Mac)
- Job dependencies (`needs:`) — CD only runs if CI passes
- Reusable workflows and composite actions (preview)

---

### Sprint 23 — GitOps with Argo CD 🔨
**Topic:** Pull-based continuous deployment — Argo CD watches git and deploys automatically
**Duration:** 35 min
**Sprint type:** Build — installs Argo CD, writes Application manifest
**Done condition:** Push a K8s manifest change to the repo. Argo CD detects it within 3 minutes and applies it to the cluster automatically.

**The analogy:**
Traditional CD pushes to the cluster (pipeline → cluster). GitOps inverts this: the cluster watches the repo and pulls changes. Git is the single source of truth. If someone manually changes something in the cluster, Argo CD reverts it. The repo is always right. Drift is impossible because the system continuously reconciles.

Connect to Vela's background: This is the runbook principle applied to infrastructure — the documented state (in git) is authoritative, not the live system. She's seen environments drift from their documentation. GitOps prevents that drift at the infrastructure level.

---

### Sprint 24 — Prometheus 🔨
**Topic:** Metrics collection — scraping and storing time-series data from Runmatic
**Duration:** 35 min
**Sprint type:** Build — deploys Prometheus, configures scrape targets, verifies custom metrics
**Done condition:** Prometheus scraping Runmatic API. Custom metrics visible in Prometheus UI: `runbook_staleness_days`, `api_request_duration_seconds`, `runbook_total`.

**The analogy:**
Prometheus is a poller that visits every service every 15 seconds and asks "how are you doing?" Services expose a `/metrics` endpoint in a specific text format — Prometheus records the numbers and timestamps them. This is pull-based: Prometheus comes to get data, services don't push it. If Prometheus is down, services just continue. When it comes back, it picks up where it left off.

Connect to Vela's background: She's a Splunk expert — log-based monitoring. Prometheus is the metrics-based complement. Logs answer "what happened and when." Metrics answer "how much, how fast, how often, right now." Both are necessary.

---

### Sprint 25 — Grafana Dashboards 🔨
**Topic:** Visualizing Prometheus metrics — building SLO-based operational dashboards
**Duration:** 35 min
**Sprint type:** Build — builds Grafana dashboard with Runmatic SLO panels
**Done condition:** Grafana dashboard showing: API request rate, error rate, p99 latency, runbook staleness distribution by service, worker job throughput.

**This is Vela's home turf translated to a new tool.** She's spent 13 years building Splunk dashboards. The thinking is identical — what questions does the on-call engineer need answered at 2am? PromQL is the query language; Grafana is the visualization layer. The skill transfer is direct.

**Key concepts:**
- PromQL fundamentals: rate(), histogram_quantile(), sum by(), label_values()
- The four golden signals: latency, traffic, errors, saturation
- SLO dashboards vs exploratory dashboards
- Alert thresholds on panels
- Dashboard provisioning via ConfigMap (infrastructure as code for dashboards)

---

### Sprint 26 — Alerting 🔨
**Topic:** Prometheus alerting rules and Alertmanager routing
**Duration:** 35 min
**Sprint type:** Build — writes alerting rules, configures Alertmanager with Slack routing
**Done condition:** Alert fires in Slack when any runbook hasn't been verified in 7 days. Alert resolves in Slack when the runbook is verified.

**The analogy:**
An alert is a question asked on a schedule: "Is this condition true right now? Has it been true for longer than X minutes?" Alert fatigue — too many low-quality alerts — is the #1 reason on-call engineers burn out and miss real incidents. Good alerting is about signal-to-noise ratio, not maximum coverage. Every alert should be actionable, have a clear owner, and link to a runbook. (Runmatic is that runbook system.)

Connect to Vela's background: She's been paged. She knows the difference between "this alert woke me up and nothing was wrong" and "this alert woke me up and the system was on fire." Alert design is about making only the second type exist.

---

### Sprint 27 — Log Aggregation with Loki 🔨
**Topic:** Centralized logging — Loki + Promtail + Grafana unified observability
**Duration:** 35 min
**Sprint type:** Build — deploys Loki stack, queries Runmatic logs via Grafana
**Done condition:** All 5 Runmatic service logs queryable in Grafana via Loki. LogQL query showing error rate by service over the last hour.

**This is Vela's deepest expertise applied to a new tool.** Loki is conceptually Splunk — log aggregation with a query language (LogQL vs SPL). The key difference: Loki is label-indexed (like Prometheus for logs), not full-text indexed. Cheaper, faster for label-based queries, less flexible for full-text search.

The unified Grafana view — metrics from Prometheus, logs from Loki, in the same dashboard — is the modern observability stack. This sprint brings everything together.

---

### Sprint 28 — AWS Foundations 🔨
**Topic:** VPC, IAM, ECR — the AWS baseline for production Runmatic
**Duration:** 35 min
**Sprint type:** Build — Terraform for VPC and ECR, IAM role configuration
**Done condition:** AWS VPC with public/private subnets. ECR registry created. Runmatic images pushed to ECR. IAM role configured with least-privilege permissions.

**Key concepts:**
- VPC: CIDR blocks, subnets, Internet Gateway, NAT Gateway — why private subnets for databases
- IAM principle of least privilege — why the EKS role should not have AdministratorAccess
- ECR image lifecycle policies — automatic cleanup of old image tags
- Terraform init/plan/apply workflow — infrastructure as code
- AWS regions and availability zones — why multi-AZ matters

---

### Sprint 29 — EKS 🔨
**Topic:** Managed Kubernetes on AWS — deploying Runmatic to EKS
**Duration:** 35 min
**Sprint type:** Build — Terraform for EKS cluster, deploy Runmatic manifests
**Done condition:** EKS cluster running. Runmatic deployed from ECR images. Accessible via AWS Load Balancer.

**Key concepts:**
- EKS control plane (managed by AWS) vs worker nodes (your responsibility)
- Node groups and managed node groups
- kubeconfig for EKS (`aws eks update-kubeconfig`)
- AWS Load Balancer Controller
- IRSA (IAM Roles for Service Accounts) — pods get AWS permissions without static credentials

---

### Sprint 30 — RDS 🔨
**Topic:** Moving PostgreSQL from K8s to AWS RDS managed database
**Duration:** 35 min
**Sprint type:** Build — Terraform for RDS, updates K8s Secrets with RDS endpoint
**Done condition:** Runmatic using RDS PostgreSQL. K8s postgres StatefulSet removed. Automated backups confirmed in RDS console.

**The mental model:** Running a database in K8s requires you to own backups, failover, patching, and performance tuning. RDS handles all of that. The tradeoff: less control, significantly less operational burden. This sprint is about knowing when to use managed services vs self-managed — a judgment call every senior SRE makes.

---

### Sprint 31 — Security Hardening 🔨
**Topic:** Non-root containers, vulnerability scanning, secrets management
**Duration:** 35 min
**Sprint type:** Build — Dockerfile security updates, Trivy scan, AWS Secrets Manager integration
**Done condition:** All containers run as non-root users. Trivy scan shows zero critical CVEs. Database password sourced from AWS Secrets Manager via IRSA.

**Key concepts:**
- USER instruction in Dockerfile — why root in containers is dangerous
- SecurityContext in K8s: runAsNonRoot, readOnlyRootFilesystem, allowPrivilegeEscalation: false
- Trivy for image vulnerability scanning
- AWS Secrets Manager vs K8s Secrets — the upgrade for production
- IRSA — pods authenticate to AWS without static credentials

---

### Sprint 32 — Act 3 Capstone 🏁
**Topic:** Production Runmatic — the final demonstration
**Duration:** 35 min (will extend — this is the portfolio capstone)
**Sprint type:** Capstone

**Vela must demonstrate:**
1. Push a code change to main → CI runs → image built and pushed to ECR → Argo CD deploys to EKS → Runmatic updated in production (end-to-end in one demonstration)
2. Open Grafana → show live Runmatic metrics: request rate, error rate, latency
3. Open Loki → query logs for a specific time range, filter by service
4. Manually trigger a staleness condition → Slack alert fires → acknowledge in Alertmanager
5. Walk through the full architecture from browser to database, naming every component and why each decision was made
6. Show the Terraform state — infrastructure fully defined as code

**Final capstone scoring (out of 50):**
- Architecture explanation (15): Complete, accurate, covers every component
- Live demonstration (20): Pipeline to production works. Monitoring works. Alerting works.
- Documentation quality (15): All 32 sprint folders complete. CHANGELOG.md tells the full story.

**Completion condition:** Score 40+/50. If below 40, identify the gap and address it before calling the project complete.

**After passing:** Claude writes the final CHANGELOG.md entry. PROGRESS.md is marked complete. The GitHub repo is the portfolio artifact.
