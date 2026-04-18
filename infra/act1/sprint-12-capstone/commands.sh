#!/bin/bash
# Sprint 12 — Act 1 Capstone
# Goal: Prove Docker mastery across operational proof, architecture explanation, and documentation quality
# This is a proof-of-mastery session — no new infrastructure built

# ═══════════════════════════════════════════════════════════════════════════
# PART 1 — OPERATIONAL PROOF
# ═══════════════════════════════════════════════════════════════════════════

# === Verify all 5 services are running and healthy ===

# why: Capstone requirement — demonstrate the full stack works end-to-end
docker compose ps

# Expected output:
# api1        runmatic-api-v2                       Up (healthy)
# frontend1   sprint-11-restart-policies-frontend   Up
# postgres1   postgres:15-alpine                    Up (healthy)
# redis1      redis:7-alpine                        Up (healthy)
# worker1     runmatic-worker-v1                    Up


# === Create runbook via browser UI ===

# why: Demonstrate the application actually works, not just the containers
# Manual step: Open http://localhost:3001
# Click "+ New Runbook"
# Fill in:
#   Title: API Health check failure
#   Service: runmatic-api
#   Content: check status investigate Take action
# Click "Create Runbook"


# === Verify runbook was created in database ===

# why: Confirm UI → API → postgres flow works
docker exec postgres1 psql -U runmatic -d runmatic -c "SELECT id, title, status, created_at FROM runbooks"

# Expected: See 5 rows, including the new runbook with today's created_at timestamp


# === Test persistence — full compose down/up cycle ===

# why: Prove that volumes work — data survives container lifecycle
docker compose down

# what I saw: All containers removed, network removed, volume still exists

# Verify volume still exists after down
docker volume inspect sprint-11-restart-policies_postgres-data

# Expected: Volume created_at shows April 15, still present on April 18

# Bring stack back up
docker compose up -d

# Verify runbook still exists after restart
docker exec postgres1 psql -U runmatic -d runmatic -c "SELECT id, title FROM runbooks"

# Expected: All 5 runbooks still present, including ID 5 created today


# === Test restart policy — manual stop vs crash ===

# why: Demonstrate understanding of `unless-stopped` policy behavior
# Manual stop should NOT trigger restart (operator intent respected)
# Crash should trigger restart (automatic recovery)

# First, try manual stop (this should NOT restart)
# docker compose kill api
# Result: Container stops, does not restart — correct behavior for unless-stopped

# Now simulate a real crash by killing PID 1 inside the container
# why: This simulates an actual application crash, not a manual stop
docker compose exec api sh -lc 'kill 1'

# what I saw: Container immediately restarts

# Verify restart happened
docker compose ps

# Expected output:
# api1 shows "Up 1 second (health: starting)" — uptime reset, health check starting

# Wait a few seconds for health check to pass
sleep 10
docker compose ps

# Expected output:
# api1 shows "Up 5 seconds (healthy)" — uptime different from other services
# All other services show "Up 6 minutes" — they didn't restart


# === Observe health check transitions ===

# why: Demonstrate understanding that restart policy + health checks work together
# After restart, API goes: starting → healthy based on health check interval (10s)

docker compose logs api --tail 20

# Expected: See "Runmatic API starting" log, followed by health check pings


# ═══════════════════════════════════════════════════════════════════════════
# PART 2 — ARCHITECTURE EXPLANATION (Verbal)
# ═══════════════════════════════════════════════════════════════════════════

# These were verbal explanations, not commands. Documented in notes.md.
# Questions answered:
# Q1: Network topology — which services connect to which, using what hostnames
# Q2: Volume strategy — what's persistent vs ephemeral, and why
# Q3: Dockerfile layer ordering — why order affects build speed
# Q4: Startup dependency chain — what depends on what, how health checks enforce it


# ═══════════════════════════════════════════════════════════════════════════
# PART 3 — DOCUMENTATION QUALITY AUDIT
# ═══════════════════════════════════════════════════════════════════════════

# === Verify all sprints have complete documentation ===

# why: Capstone requirement — demonstrate complete audit trail from Sprint 01 to 11
find infra/act1 -type f \( -name "SCORE.md" -o -name "notes.md" -o -name "commands.sh" \) | sort

# Expected: 33 files (3 per sprint × 11 sprints)


# === Spot check file sizes ===

# why: Ensure files are substantial, not empty placeholders
wc -l infra/act1/sprint-05-volumes/SCORE.md \
     infra/act1/sprint-10-multistage/notes.md \
     infra/act1/sprint-11-restart-policies/commands.sh

# Expected output:
#       43 infra/act1/sprint-05-volumes/SCORE.md
#      147 infra/act1/sprint-10-multistage/notes.md
#      118 infra/act1/sprint-11-restart-policies/commands.sh


# === Verify infrastructure artifacts present in build sprints ===

# why: Ensure not just documentation exists, but actual deliverables (Dockerfiles, compose files)
for dir in infra/act1/sprint-0{3..9}-* infra/act1/sprint-1{0,1}-*; do
  echo "=== $(basename $dir) ==="
  ls -1 "$dir" | grep -E "Dockerfile|docker-compose\.yml"
done

# Expected:
# sprint-03: Dockerfile.api, Dockerfile.worker
# sprint-07: docker-compose.yml (first compose file)
# sprint-08: docker-compose.yml (redis added)
# sprint-09: docker-compose.yml, Dockerfile.frontend
# sprint-10: docker-compose.yml, Dockerfile.api (multi-stage), Dockerfile.frontend (multi-stage)
# sprint-11: docker-compose.yml (with restart policies and health checks)


# ═══════════════════════════════════════════════════════════════════════════
# CAPSTONE COMPLETE
# ═══════════════════════════════════════════════════════════════════════════

# Score: 29/30
# Operational Proof:       10/10 — All services healthy, runbook created, persistence verified,
#                                   restart policy tested correctly, health checks observed
# Architecture Explanation: 9/10 — Network topology, volume strategy, layer caching, startup chain
#                                   all explained correctly (minor: could name specific network)
# Documentation Quality:   10/10 — All 11 sprints fully documented, files substantial, infra complete

# Act 1 Complete — Docker Mastery Proven
# Act 2 Unlocked — Kubernetes (Sprint 13-20)
