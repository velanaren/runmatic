#!/bin/bash
# Sprint 11 — Health Checks & Restart Policies
# Goal: Make Runmatic self-healing with restart policies and graceful shutdown
# Key question: What's the difference between a container crash (Docker can fix) and a container being unhealthy (human must fix)?

# === Initial state — no restart policy ===

# why: see what happens when a container is force-killed without a restart policy
# what I saw: API exited with code 137 (SIGKILL) and stayed stopped — no automatic restart
docker compose up -d
docker compose kill api
docker compose ps

# why: check if the container is actually stopped, not just unhealthy
# what I saw: STATUS showed stopped, not running
docker compose ps api

# === Building the restart policy configuration ===

# Created: infra/act1/sprint-11-restart-policies/docker-compose.yml
# Added to all 5 services:
#   restart: unless-stopped
# Added to postgres and worker:
#   stop_grace_period: 30s
# Added to API:
#   healthcheck with curl -f http://localhost:8000/health

# === Test 1: Automatic restart after crash ===

# why: bring up the stack with new restart policies
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml up -d

# why: see all services with their health status
# what I saw: all services Up, postgres and redis showing (healthy), API showing (health: starting)
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml ps

# why: simulate operator killing the container (manual intervention)
# what I saw: container stayed stopped — unless-stopped respects manual intervention
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml kill api
sleep 3
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml ps api

# why: check restart count to verify no restart happened
# what I saw: 0 — correct behavior, docker compose kill is manual intervention
docker inspect api1 --format '{{.RestartCount}}'

# why: simulate a REAL crash from inside the container (not manual kill from outside)
# what I saw: kill binary not available, used shell builtin instead
# Result: container automatically restarted
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml exec api sh -lc 'kill 1'
sleep 3

# why: verify restart actually happened
# what I saw: 1 — restart policy triggered on real crash
docker inspect api1 --format '{{.RestartCount}}'

# why: confirm container is back up
# what I saw: Up with recent uptime (seconds, not minutes)
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml ps api

# === Test 2: Graceful shutdown ===

# why: send SIGTERM (graceful stop request) and observe clean shutdown
# what I saw: API exited with code 0 (clean exit)
# Logs showed graceful shutdown message from Uvicorn
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml stop api

# === Test 3: Health check validation ===

# why: restart API and watch health check transition
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml up -d

# why: observe health check status progression
# what I saw:
#   - Initially: Up (health: starting)
#   - After ~10 seconds (start_period): Up (healthy)
# Full chain: postgres healthy → redis healthy → api starts → api healthy → worker starts
docker compose -f infra/act1/sprint-11-restart-policies/docker-compose.yml ps

# === Phase 3 Challenge: Understanding unhealthy vs crashed ===

# Scenario: Container is running but unhealthy
# My reasoning:
# - Container crash (exit) → restart policy triggers → Docker fixes automatically
# - Container unhealthy (running but failing health check) → restart does NOT trigger → requires human diagnosis
# Why: restarting unhealthy container would create restart loop without fixing root cause
# Response: check logs, verify dependencies, inspect health check output

# === Bonus Challenge: Worker shell form CMD issue ===

# Scenario: Worker starts, connects to Redis, but jobs don't execute

# why: check what processes are running inside the worker container
# what I saw:
#   PID 1: /bin/sh -c python -m worker.main  (shell wrapper)
#   PID 7: python -m worker.main             (actual worker)
# Problem: shell form CMD creates shell as PID 1, which doesn't forward signals
docker compose exec worker ps aux

# My diagnosis:
# - Shell form CMD wraps process in /bin/sh as PID 1
# - Signals (SIGTERM, job scheduling signals) go to PID 1 (shell), don't reach PID 7 (Python)
# - Breaks both graceful shutdown AND job execution

# Fix applied: Changed docker-compose.yml worker command
# FROM: command: python -m worker.main               (shell form)
# TO:   command: ["python", "-m", "worker.main"]     (exec form)

# why: verify Python is now PID 1 (no shell wrapper)
# what I saw: PID 1 is now python -m worker.main directly
docker compose exec worker ps aux

# why: verify graceful shutdown now works
# what I saw: SIGTERM goes directly to Python, clean exit
docker compose stop worker

# Result: Jobs execute correctly, graceful shutdown works
# Lesson: Always use exec form (JSON array) for service commands — shell form breaks signal handling
