#!/bin/bash
# Sprint 03 — Writing Dockerfiles
# Goal: Write a production-ready Dockerfile for the Runmatic API
# Key question: Why does the order of COPY instructions matter for build speed?

# === Phase 1: Understanding the build context ===

# why: Check what files the API needs (the build context)
ls -la app/api/
# what I saw: app/, migrations/, alembic.ini, requirements.txt

# === Phase 2: First build — correct layer order ===

# why: Build the image from the Dockerfile I wrote
# Build context is app/api — this is where all required files are
docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api

# what I saw: Each COPY and RUN created a new layer
# Build completed successfully

# === Phase 3: Run the container ===

# why: Start the API container to verify it works
docker run -d -p 8000:8000 --name api-test runmatic-api-v1

# why: Check if container is running
docker ps

# why: Test the health endpoint
curl localhost:8000/health
# what I saw: {"status":"degraded","db":"disconnected",...}
# This is correct — config not injected yet (Sprint 04 topic)

# why: Check logs to confirm uvicorn started
docker logs api-test

# why: Clean up
docker stop api-test && docker rm api-test

# === Phase 4: Layer caching experiment #1 — Code change with correct order ===

# why: Make a small change to test caching (added a comment to main.py)
# Dockerfile order:
#   1. FROM python:3.11-slim
#   2. WORKDIR /app
#   3. COPY requirements.txt .
#   4. COPY alembic.ini .
#   5. RUN pip install
#   6. COPY migrations
#   7. COPY app ./app  ← changed

# why: Rebuild with timing to measure cache effectiveness
time docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api

# what I saw:
# [+] Building 0.1s
# => CACHED [2/7] WORKDIR /app
# => CACHED [3/7] COPY requirements.txt .
# => CACHED [4/7] COPY alembic.ini .
# => CACHED [5/7] RUN pip install
# => CACHED [6/7] COPY migrations
# => [7/7] COPY app ./app  ← ONLY this layer rebuilt

# Build time: 0.1s
# KEY INSIGHT: Layers 1-6 cached. Only Layer 7 (app code) rebuilt.

# === Phase 5: Layer caching experiment #2 — Wrong order to prove cache invalidation ===

# why: Move COPY app command BEFORE pip install to demonstrate cache invalidation
# (Temporarily edited Dockerfile to test — reverted after)
# New order:
#   1. FROM python:3.11-slim
#   2. WORKDIR /app
#   3. COPY app ./app  ← moved up (changed)
#   4. COPY requirements.txt .
#   5. COPY alembic.ini .
#   6. RUN pip install  ← rebuilds because layer 3 changed
#   7. COPY migrations

# Made another comment change to main.py, then rebuilt
time docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api

# what I saw:
# [+] Building 29.5s
# => CACHED [2/7] WORKDIR /app
# => [3/7] COPY app ./app  ← changed
# => [4/7] COPY requirements.txt .  ← rebuilds
# => [5/7] COPY alembic.ini .       ← rebuilds
# => [6/7] RUN pip install          ← rebuilds (takes 28.8s!)
# => [7/7] COPY migrations          ← rebuilds

# Build time: 29.5s (vs 0.1s with correct order)
# KEY INSIGHT: Changing layer 3 invalidated cache for ALL layers after it.
# pip install reran unnecessarily, wasting 28.8 seconds.

# Comparison:
# Correct order (app code last):      0.1s build
# Wrong order (app code early):       29.5s build
# Difference: 295x slower

# === Phase 6: Understanding EXPOSE vs -p ===

# why: Check if EXPOSE in Dockerfile actually publishes the port
# Dockerfile has: EXPOSE 8000

# Try running without -p flag
docker run -d --name api-no-port runmatic-api-v1
curl localhost:8000/health
# Result: Connection refused

# why: EXPOSE is documentation only. It doesn't publish the port.
# -p publishes. EXPOSE documents.

docker stop api-no-port && docker rm api-no-port

# === Phase 7: Verify exec form CMD ===

# why: Check that CMD uses exec form (not shell form) for proper signal handling
docker image inspect runmatic-api-v1 --format '{{.Config.Cmd}}'
# Output: [uvicorn app.main:app --host 0.0.0.0 --port 8000]
# ✅ This is exec form (array) — process runs as PID 1, receives SIGTERM correctly

# If it were shell form, output would be: [/bin/sh -c uvicorn app.main:app...]
# That would be wrong — shell as PID 1 doesn't forward signals

# === Phase 8: Test graceful shutdown ===

# why: Verify that exec form CMD allows graceful shutdown
docker run -d --name api-graceful -p 8000:8000 runmatic-api-v1

# why: Send SIGTERM (what docker stop does)
time docker stop api-graceful
# what I saw: Stopped in < 2 seconds
# If shell form were used, it would hang for 10 seconds then SIGKILL

docker rm api-graceful

# === Key Takeaways ===
# 1. Layer order = build speed. Most stable → top, most changing → bottom.
# 2. EXPOSE documents. -p publishes. EXPOSE alone does nothing for connectivity.
# 3. Exec form CMD = PID 1 = proper SIGTERM handling = graceful shutdown.
# 4. Shell form CMD = shell as PID 1 = signals lost = 10s timeout + SIGKILL.
# 5. Caching works bottom-up. Change a layer → all layers AFTER it rebuild.
