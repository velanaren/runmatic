#!/bin/bash
# Sprint 04 — Environment & Configuration
# Goal: Inject config at runtime via env vars. Same image, different environments.
# Key question: Why can't we bake DATABASE_URL and SECRET_KEY into the Dockerfile?

# === Phase 1: Understanding what the API needs ===

# why: Check if Dockerfile from Sprint 03 has any hardcoded ENV or ARG variables
grep -n "ENV\|ARG\|DATABASE\|SECRET\|REDIS\|HOST\|PORT" infra/act1/sprint-03-dockerfiles/Dockerfile.api
# what I saw: No results. Clean Dockerfile with no hardcoded config.

# why: Find where the API actually reads its config from
# what I saw: app/api/app/config.py uses pydantic-settings with 6 env vars:
#   Required (crash if missing): DATABASE_URL, REDIS_URL, SECRET_KEY
#   Optional (have defaults): ENVIRONMENT, LOG_LEVEL, CORS_ORIGINS

# === Phase 2: The crash test — what happens with no env vars ===

# why: Build the image from Sprint 03's Dockerfile
docker build -t runmatic-api-v11 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api

# why: Run container with NO env vars to see the pydantic validation error
docker run --rm -p 8000:8000 runmatic-api-v11
# what I saw: pydantic_core.ValidationError: 3 validation errors for Settings
#   DATABASE_URL Field required
#   REDIS_URL Field required
#   SECRET_KEY Field required
# This is GOOD — the app refuses to start with missing config instead of silently failing later

# === Phase 3: Inject config with -e flags ===

# why: Created .env.example in sprint folder with all 6 vars documented (placeholder values)
# Content: DATABASE_URL, REDIS_URL, SECRET_KEY, ENVIRONMENT, LOG_LEVEL, CORS_ORIGINS

# why: Run container injecting all 6 env vars with -e flags
docker run --rm -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:runmatic@localhost:5432/runmatic \
  -e REDIS_URL=redis://localhost:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  -e ENVIRONMENT=development \
  -e LOG_LEVEL=INFO \
  -e CORS_ORIGINS=http://localhost:3000 \
  runmatic-api-v11
# what I saw: Container started successfully. No pydantic errors.

# why: Check health endpoint to confirm config was read correctly
curl localhost:8000/health
# what I saw: {"status":"degraded","db":"disconnected","cache":"disconnected",...}
# This is CORRECT — config injection worked. App started, read env vars, tried to connect
# to postgres/redis (they're not running, but that's a different problem).
# "degraded" = "I'm alive, I know my config, but dependencies aren't ready yet"

# === Phase 4: Use --env-file instead of 6 -e flags ===

# why: Cleaner method — one flag pointing at .env.example file
docker run --rm -p 8000:8000 --env-file infra/act1/sprint-04-env-config/.env.example runmatic-api-v11

# why: Confirm same result
curl localhost:8000/health
# what I saw: Same "degraded" response. Config injection works both ways.

# === Phase 5: Security inspection ===

# why: Check if env vars (including secrets) are visible in docker inspect
docker inspect $(docker ps -q --filter ancestor=runmatic-api-v11) | grep -A 20 '"Env"'
# what I saw: ALL env vars visible, including SECRET_KEY=dev-secret-key-not-for-production
# KEY INSIGHT: This proves why ENV in Dockerfile is dangerous for secrets.
# Anyone with docker access on the host can see the values via inspect.

# === Phase 6: Verify .gitignore protects real secrets ===

# why: Check if .env is already in .gitignore
cat .gitignore | grep "^\\.env$"
# what I saw: .env is present in .gitignore

# why: Test that git actually ignores .env files
echo "SECRET_KEY=real-production-secret" > .env
git status
# what I saw: .env did NOT appear in untracked files. Gitignore working correctly.

# why: Clean up test file
rm .env

# === Key Takeaways ===
# 1. Config must be injected at runtime, never baked into the image
# 2. -e flags or --env-file both work. --env-file is cleaner for multiple vars.
# 3. docker inspect exposes all env vars — so env vars are NOT secure for real secrets
# 4. .env.example (template with placeholders) gets committed
# 5. .env (real values) must be gitignored
# 6. Production uses secret managers (Vault, AWS Secrets Manager), not .env files
