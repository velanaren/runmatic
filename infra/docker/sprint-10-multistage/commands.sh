#!/bin/bash
# Sprint 10 — Multi-Stage Builds & Image Optimization
# Goal: Reduce image sizes by separating build-time from runtime dependencies
# Key question: When does multi-stage give massive savings vs minimal savings?

# === Baseline Measurement ===

# why: Establish baseline sizes before optimization to measure impact
docker image ls | grep runmatic

# what I saw:
# runmatic-api-v1      279 MB
# runmatic-worker-v1   210 MB
# frontend             338 MB
# Frontend is 338MB just to serve ~5MB of static files — carrying entire Node.js toolchain


# === Frontend Multi-Stage Build ===

# why: Separate npm build (needs Node.js 600MB) from runtime serving (needs nginx 30MB)
# Created: infra/docker/sprint-10-multistage/Dockerfile.frontend
# Stage 1: FROM node:18-alpine AS builder → npm ci → npm run build → produces /app/dist
# Stage 2: FROM nginx:alpine → COPY --from=builder /app/dist → COPY nginx.conf → serve

# Build the optimized frontend image
docker compose build frontend

# Result: 338 MB → 53.8 MB = 84% reduction (target was 60%)
# Node.js, npm, node_modules, TypeScript compiler all discarded — only 5MB of HTML/CSS/JS remains


# === API Multi-Stage Build ===

# why: Separate pip install (needs pip + gcc) from runtime (needs only installed packages)
# Created: infra/docker/sprint-10-multistage/Dockerfile.api
# Stage 1: FROM python:3.11 AS builder → pip install --prefix=/install
# Stage 2: FROM python:3.11-slim → COPY --from=builder /install /usr/local → COPY app code

# Build the optimized API image
docker compose build api

# Result: 279 MB → 268 MB = 4% reduction (target was 50%)
# Why so small? pip + gcc discarded (130MB), but Python packages must stay (119MB)
# Python is interpreted — packages are runtime dependencies, not build artifacts


# === Size Comparison ===

# why: Verify actual reduction percentages
docker image ls | grep -E "frontend|api" | grep -v worker

# Frontend: 84% smaller — Node.js completely gone
# API: 4% smaller — only build tools gone, packages remain


# === Verify Everything Still Works ===

# why: Image size reduction is meaningless if functionality breaks
docker compose down
docker compose up -d

# Check all services healthy
docker compose ps

# Verify API health endpoint
curl localhost:3001/api/health

# what I saw: All services running, health check clean, UI loads
# Optimization successful — both images smaller AND still functional


# === Investigation: Why the Asymmetry? ===

# why: Understand when multi-stage gives big wins vs small wins
docker image ls | grep python

# Compared layers between single-stage and multi-stage
docker image history runmatic-api-v1 | head -20
docker image history runmatic-api-multistage | head -20

# Key insight:
# Frontend: build tools (npm) are ONLY needed at build time. Runtime needs compiled output (static files).
# API: build tools (pip) are only needed at build time, but PACKAGES are needed at runtime.
#
# Formula: Savings = (build tools discarded) + (base image downgrade) - (runtime artifacts that must stay)
#
# Frontend: 280MB tools discarded, 5MB artifacts remain = 84% win
# API: 130MB tools discarded, 119MB packages remain = 4% win


# === Bonus Challenge: Missing nginx.conf ===

# Scenario: Teammate's Dockerfile builds but Nginx crashes with "nginx.conf not found"
# Their mistake: COPY nginx.conf in builder stage, expecting it to exist in runtime stage

# Simulated the bug by moving COPY nginx.conf to builder stage
# Result: Build succeeds, runtime crashes — nginx.conf was discarded with the builder stage

# Root cause: Each FROM starts a fresh filesystem. Files don't leak between stages.
# Fix: Move COPY nginx.conf to runtime stage (after FROM nginx:alpine)

# Verified fix works
docker compose up -d frontend
docker compose logs frontend

# Diagnosis: 5/5 — correctly identified builder stage discard
# Fix: 5/5 — moved COPY to runtime stage
# Total: 10/10
