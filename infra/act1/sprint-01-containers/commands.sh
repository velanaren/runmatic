#!/bin/bash
# Sprint 01 — Containers & the Docker Mental Model
# Goal: Understand what a container actually is and the Docker 3-layer architecture
# Key question: What's the difference between an image and a container?

# === Phase 1: Running your first container ===

# why: Start Redis in foreground mode to see real-time logs
# what I expected: Container would start and return prompt
# what actually happened: Terminal blocked — attached to container's stdout
docker run --name redis-test -p 6379:6379 redis:7-alpine
# Ctrl+C to stop

# === Phase 2: Managing container lifecycle ===

# why: Check what containers are currently running
docker ps

# why: Inspect full metadata — network settings, env vars, everything Docker knows
docker inspect redis-test

# why: Stop the container gracefully (sends SIGTERM)
docker stop redis-test

# why: Check if container is gone
docker ps
# what I saw: redis-test disappeared from running containers

# why: Check if container REALLY gone or just stopped
docker ps -a
# what I saw: redis-test still exists with status "Exited" — not deleted, just stopped

# === Phase 3: Running in detached mode ===

# why: Start container in background (-d = detached) so terminal returns immediately
docker run -d --name redis-test2 -p 6379:6379 redis:7-alpine

# why: Confirm it's running in background
docker ps

# why: Read logs from a detached container
docker logs redis-test2

# why: Clean up — remove stopped containers (must stop first if running)
docker rm redis-test

# === Key concepts demonstrated ===
# 1. Container lifecycle: run → running → stop → stopped → rm → removed
# 2. Foreground vs detached mode (-d flag)
# 3. docker ps vs docker ps -a (running vs all containers)
# 4. Port mapping (-p host:container) is required to reach container from host
# 5. Containers can be stopped but still exist — must explicitly rm to delete

# === Phase 4: Break-Fix Challenge ===

# Problem: Colleague says "Redis is running but I can't connect"
# Command they ran:
docker run -d --name redis-broken redis:7-alpine

# Diagnosis steps:
# 1. docker ps — shows container running, but PORTS column shows only "6379/tcp" (no mapping)
# 2. docker inspect redis-broken — PortBindings section is empty
# 3. docker logs redis-broken — container logs show Redis listening on 6379 (Redis is healthy)
# 4. redis-cli -h localhost -p 6379 ping — Connection refused

# Root cause: No port mapping. Container is isolated — host can't reach it.

# Fix:
docker rm -f redis-broken
docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine

# Verification:
redis-cli -h localhost -p 6379 ping
# Output: PONG ✅
# docker ps now shows: 0.0.0.0:6379->6379/tcp

# === Phase 5: Bonus Challenge ===

# Problem: Container name conflict
# Scenario: Stop redis-fixed, then try to run a new container with same name
docker stop redis-fixed
docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine
# Error: "Conflict. The container name '/redis-fixed' is already in use"

# Why it fails:
# - docker stop = container still exists (status: Exited)
# - docker run = creates NEW container, needs unique name
# - Docker's internal ledger shows redis-fixed still exists
# - Must rm before reusing the name

# Diagnosis:
docker ps -a | grep redis-fixed
# Shows: redis-fixed with status "Exited (0)"

docker inspect redis-fixed
# Shows: "Dead": false — container exists, just not running

# Solution:
docker rm redis-fixed
docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine
# Now it works ✅

# Alternative: Use docker run --rm to auto-delete when stopped
docker run -d --rm --name redis-temp -p 6380:6379 redis:7-alpine
docker stop redis-temp
docker ps -a | grep redis-temp
# Nothing — container auto-removed
