#!/bin/bash
# Sprint 07 — Docker Compose v1
# Goal: Replace manual docker run commands with declarative docker-compose.yml
# Key question: How does Compose simplify multi-container orchestration?

# === Phase 1: Verify Compose version ===

# why: Check that Docker Compose is installed
docker compose version
# what I saw: Docker Compose version v2.38.2-desktop.1
# KEY INSIGHT: v2 uses "docker compose" (space), not "docker-compose" (hyphen)

# === Phase 2: Write docker-compose.yml and start the stack ===

# why: Create sprint directory
mkdir -p infra/docker/sprint-07-compose-v1

# why: Write docker-compose.yml defining API + postgres + redis
# (File created manually with vim/editor)
# Contents:
#   services:
#     postgres: postgres:15-alpine with volume, env vars, no published ports
#     redis: redis:7-alpine, no published ports
#     api: runmatic-api-v1, ports 8000:8000, depends_on postgres & redis
#   volumes:
#     postgres-data: (named volume for postgres persistence)

# why: Start the entire stack with one command
cd infra/docker/sprint-07-compose-v1
docker compose up
# what I saw:
#   [+] Running 3/3
#    ✔ Container redis1     Created
#    ✔ Container postgres1  Created
#    ✔ Container api1       Created
#   Attaching to api1, postgres1, redis1
#
# Logs showed:
#   - redis and postgres started first (in parallel)
#   - postgres: "database system is ready to accept connections"
#   - api started after (due to depends_on)
#   - api: "Running Alembic migrations"
#   - api: "Started server process"
#
# KEY INSIGHT: Compose understood dependency order from depends_on.
#              Logs are combined and color-coded by service.

# === Phase 2: Verify health and service status ===

# why: Check API health endpoint
curl localhost:8000/health
# what I saw: {"status":"healthy","db":"connected","cache":"connected","details":{}}
# KEY INSIGHT: API connected to postgres and redis using service names as hostnames

# why: Check service status table
docker compose ps
# what I saw:
#   NAME        IMAGE                COMMAND      SERVICE    STATUS         PORTS
#   api1        runmatic-api-v1      "uvicorn..." api        Up 2 minutes   0.0.0.0:8000->8000/tcp
#   postgres1   postgres:15-alpine   "docker-..." postgres   Up 2 minutes   5432/tcp
#   redis1      redis:7-alpine       "docker-..." redis      Up 2 minutes   6379/tcp
#
# KEY INSIGHT:
#   - Service name (postgres) is DNS hostname
#   - Container name (postgres1) is just a label
#   - postgres/redis show internal ports only (5432/tcp, 6379/tcp)
#   - API shows published port (0.0.0.0:8000->8000/tcp)

# === Testing Persistence ===

# why: Stop and remove containers, keep volumes
docker compose down
# what I saw:
#   [+] Running 4/4
#    ✔ Container api1                        Removed
#    ✔ Container redis1                      Removed
#    ✔ Container postgres1                   Removed
#    ✔ Network sprint-07-compose-v1_default  Removed
# KEY INSIGHT: Volumes NOT removed by default

# why: Restart stack in detached mode
docker compose up -d
# what I saw:
#   [+] Running 4/4
#    ✔ Network sprint-07-compose-v1_default  Created
#    ✔ Container redis1                      Started
#    ✔ Container postgres1                   Started
#    ✔ Container api1                        Started
# KEY INSIGHT: -d runs in background (detached)

# why: Verify health after restart
curl localhost:8000/health
# what I saw: {"status":"healthy",...}
# KEY INSIGHT: Data persisted across down/up cycle

# why: Check postgres logs for persistence proof
docker compose logs postgres | grep "database system"
# what I saw:
#   postgres1  | LOG:  database system was shut down at 2026-04-11 07:40:25 UTC
#   postgres1  | LOG:  database system is ready to accept connections
# KEY INSIGHT: "was shut down" then "ready" = reused existing data, didn't reinitialize

# === Testing Volume Destruction ===

# why: Stop and remove containers AND volumes
docker compose down -v
# what I saw:
#   [+] Running 5/5
#    ✔ Container api1                             Removed
#    ✔ Container postgres1                        Removed
#    ✔ Container redis1                           Removed
#    ✔ Volume sprint-07-compose-v1_postgres-data  Removed  ← VOLUME GONE
#    ✔ Network sprint-07-compose-v1_default       Removed
# KEY INSIGHT: -v flag destroys volumes. Use with caution.

# why: Restart to see fresh initialization
docker compose up -d
# what I saw:
#   [+] Running 5/5
#    ✔ Network sprint-07-compose-v1_default         Created
#    ✔ Volume "sprint-07-compose-v1_postgres-data"  Created  ← NEW VOLUME
#    ✔ Container redis1                             Started
#    ✔ Container postgres1                          Started
#    ✔ Container api1                               Started

# why: Check postgres logs after volume deletion
docker compose logs postgres | grep "database system"
# what I saw:
#   postgres1  | The files belonging to this database system will be owned by user "postgres".
#   postgres1  | LOG:  database system is ready to accept connections
# KEY INSIGHT: "files belonging to this database system" = fresh initialization
#              Volume was gone, postgres started from scratch

# === Phase 3: Test depends_on race condition ===

# why: Remove depends_on from api service in docker-compose.yml
# (Manually edited file to remove depends_on section)

# why: Restart to observe start order without depends_on
docker compose down
docker compose up
# what I saw:
#   - All three services started
#   - Health check: {"status":"healthy",...}
#   - BUT logs showed:
#       redis ready:    07:51:28.010
#       api migrations: 07:51:28.802 (108ms later)
#       postgres ready: 07:51:28.910 (108ms after api started)
#
# KEY INSIGHT: API started BEFORE postgres was ready!
#              Worked because timing gap was only 108ms.
#              In production with slow disk, postgres might take 5-10 seconds.
#              API would crash trying to connect before postgres is ready.
#
# PROBLEM: depends_on only controls START ORDER, not READINESS.
#          It doesn't wait for postgres to be healthy.
#
# SOLUTIONS:
#   1. Health check condition:
#      postgres:
#        healthcheck:
#          test: ["CMD-SHELL", "pg_isready -U runmatic"]
#      api:
#        depends_on:
#          postgres:
#            condition: service_healthy
#
#   2. App-level retry logic (API already has this)

# === Bonus Challenge: Network Isolation ===

# why: Test what happens when services are on different networks
# Modified docker-compose.yml to add explicit network to API:
#   api:
#     networks:
#       - backend
#   networks:
#     backend:
# (postgres and redis left without networks: declaration)

# why: Start with mixed explicit/implicit networks
docker compose up
# what I saw:
#   [+] Running 6/6
#    ✔ Network sprint-07-compose-v1_default   Created
#    ✔ Network sprint-07-compose-v1_backend   Created  ← TWO NETWORKS!
#    ✔ Container postgres1                    Created
#    ✔ Container redis1                       Created
#    ✔ Container api1                         Created
# KEY INSIGHT: Compose created BOTH default and backend networks

# why: Inspect default network to see which containers are on it
docker network inspect sprint-07-compose-v1_default
# what I saw:
#   "Containers": {
#     "postgres1": {"IPv4Address": "172.23.0.2/16"},
#     "redis1":    {"IPv4Address": "172.23.0.3/16"}
#   }
# KEY INSIGHT: postgres and redis on default (no explicit networks declared)

# why: Inspect backend network to see which containers are on it
docker network inspect sprint-07-compose-v1_backend
# what I saw:
#   "Containers": {
#     "api1": {"IPv4Address": "172.24.0.2/16"}
#   }
# KEY INSIGHT: Only API on backend network

# why: Check health — this will FAIL
curl localhost:8000/health
# what I saw:
#   {"status":"degraded","db":"disconnected","cache":"disconnected",
#    "details":{"db_error":"[Errno -2] Name or service not known",
#               "cache_error":"Error -2 connecting to redis:6379"}}
# KEY INSIGHT: API can't reach postgres or redis — they're on different networks!
#
# ROOT CAUSE: When you add networks: to a service, Compose ONLY attaches
#             it to those networks (not default).
#             Services without networks: join default automatically.
#             Mixing explicit and implicit = network isolation.
#
# FIX — two options:
#   1. Remove explicit networks — everything joins default
#   2. Add networks: [backend] to postgres and redis too

# why: Fix by removing explicit networks (chose option 1)
# (Edited docker-compose.yml to remove networks: from api and networks: top-level)

# why: Restart with all services on default network
docker compose down
docker compose up -d

# why: Verify fix worked
curl localhost:8000/health
# what I saw: {"status":"healthy","db":"connected","cache":"connected",...}
# KEY INSIGHT: All services on same network = DNS resolution works

# === Cleanup ===

# why: Stop stack, keep volumes
docker compose down

# === Key Takeaways ===
# 1. docker compose up — one command starts entire stack
# 2. Compose auto-creates network (sprint-07-compose-v1_default)
# 3. Service names become DNS hostnames on that network
# 4. depends_on = start order only, NOT readiness (use health checks)
# 5. down vs down -v: down keeps volumes, down -v destroys everything
# 6. Explicit networks: means service ONLY joins those networks (not default)
# 7. Published ports (-p) for host access; containers communicate internally
# 8. Container name vs service name: service name is the DNS entry
