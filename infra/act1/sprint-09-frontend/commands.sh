#!/bin/bash
# Sprint 09 — Frontend Container
# Goal: Containerize the React UI with Nginx, serve static files, proxy API requests
# Key question: How does the browser (outside Docker) communicate with containers (inside Docker)?

# ============================================================================
# PHASE 1 — Exploration: Understanding the Build Output
# ============================================================================

# why: Check if the frontend has been compiled — browsers need HTML/CSS/JS, not TypeScript
ls -lh app/frontend/dist 2>/dev/null || echo "not built yet"
# what I saw: "not built yet" — the React app hasn't been compiled

# why: Build the React app to see what output it produces (static files for Nginx to serve)
cd app/frontend && npm run build
# what I saw:
#   dist/index.html (0.75 kB)
#   dist/assets/index-*.css (14.55 kB)
#   dist/assets/vendor-*.js (163.82 kB)
#   dist/assets/index-*.js (172.40 kB)
# Total: ~351 KB — the entire UI compiled into static files

# why: Verify the dist/ folder contains the compiled output
ls -lh app/frontend/dist
# what I saw: index.html + assets/ folder with CSS and JS bundles

# why: Check how Nginx will proxy API requests to the backend
cat app/frontend/nginx.conf
# what I saw:
#   location /api/ {
#     proxy_pass http://api:8000;  ← uses Docker DNS to find the API container
#   }

# ============================================================================
# PHASE 2 — Build: Creating the Frontend Container
# ============================================================================

# why: Create directory for this sprint's infrastructure files
mkdir -p infra/act1/sprint-09-frontend

# why: Write Dockerfile.frontend to build and serve the React app
# (File created manually with vim/VS Code — see Dockerfile.frontend for contents)
# Key decisions:
#   - Base: node:18-alpine (need Node to run npm build, Alpine for small size)
#   - Install nginx via apk (Alpine package manager)
#   - Run npm ci (clean install from package-lock.json)
#   - Run npm run build inside Dockerfile (creates dist/)
#   - Copy dist/* to /usr/share/nginx/html (where Nginx serves from)
#   - Copy nginx.conf to /etc/nginx/http.d/default.conf
#   - Expose 3000, run nginx in foreground

# why: Add frontend service to docker-compose.yml
# (Updated manually — see docker-compose.yml)
# Key config:
#   build:
#     context: ../../../app/frontend
#     dockerfile: ../../infra/act1/sprint-09-frontend/Dockerfile.frontend
#   ports: 3001:3000 (host port 3000 was already in use by Grafana)
#   depends_on: api (condition: service_healthy)

# why: Start all services with the new frontend container
docker compose up -d
# what I saw: All services started, frontend1 container created

# why: Check if the frontend container is running and healthy
docker compose ps
# what I saw: frontend1 running on port 3001

# why: Open browser to test the UI
open http://localhost:3001
# what I saw: Initially got 500 error — static files weren't being served

# why: Check Nginx logs to diagnose the 500 error
docker compose logs frontend
# what I saw: Nginx errors about missing files in /usr/share/nginx/html

# why: Fix the Dockerfile — add commands to copy dist/ to /usr/share/nginx/html
# Added to Dockerfile.frontend:
#   RUN mkdir -p /usr/share/nginx/html
#   RUN cp -r dist/* /usr/share/nginx/html/

# why: Rebuild the frontend image with the fix
docker compose build frontend

# why: Restart containers with the fixed image
docker compose up -d
# what I saw: frontend1 restarted successfully

# why: Test the UI again
open http://localhost:3001
# what I saw: Runmatic login page loaded successfully!

# ============================================================================
# Authentication Setup (Mode A fix — bcrypt library issue)
# ============================================================================

# why: Try to log in with demo credentials
# Attempted: demo@runmatic.dev / demo1234
# what I saw: "Invalid email or password" error

# why: Check if any users exist in the database
docker compose exec api python -c "
from sqlalchemy import create_engine, text
import os
engine = create_engine(os.environ['DATABASE_URL'].replace('asyncpg', 'psycopg2'))
with engine.connect() as conn:
    result = conn.execute(text('SELECT email FROM users LIMIT 5'))
    users = result.fetchall()
    if users:
        print('Users found:', [u[0] for u in users])
    else:
        print('No users in database — seed not run yet')
"
# what I saw: "No users in database"

# why: Create a demo user (encountered bcrypt library bug — fixed in Mode A)
# (After API rebuild with bcrypt==4.0.1 fix)
docker compose exec api python -c "
import asyncio
from app.auth import get_password_hash
from app.models import User
from app.database import AsyncSessionLocal
from datetime import datetime, timezone

async def create_user():
    async with AsyncSessionLocal() as session:
        user = User(
            email='demo@runmatic.dev',
            hashed_password=get_password_hash('demo1234'),
            created_at=datetime.now(timezone.utc).replace(tzinfo=None)
        )
        session.add(user)
        await session.commit()
        print('✅ User created successfully')

asyncio.run(create_user())
"
# what I saw: "✅ User created successfully"

# why: Seed the database with demo runbooks for testing
docker compose exec postgres psql -U runmatic -d runmatic -c "
INSERT INTO services (name, description, owner_team, created_at)
VALUES ('payments-api', 'Core payment processing', 'Payments Team', NOW());
"

docker compose exec postgres psql -U runmatic -d runmatic -c "
INSERT INTO runbooks (title, content_md, service_id, last_verified_at, staleness_days, status, created_at, updated_at)
VALUES
  ('Payment Gateway Failover', 'Quick runbook for payment gateway issues', 1, NOW() - INTERVAL '2 days', 2, 'fresh', NOW(), NOW()),
  ('Database Pool Exhaustion', 'How to handle connection pool issues', 1, NOW() - INTERVAL '15 days', 15, 'warning', NOW(), NOW()),
  ('On-Call Escalation', 'Escalation procedure', 1, NOW() - INTERVAL '45 days', 45, 'stale', NOW(), NOW());
"
# what I saw: 3 runbooks inserted successfully

# ============================================================================
# PHASE 3 — Challenge: Tracing a Request Through Nginx
# ============================================================================

# why: Open browser DevTools Network tab to watch API requests
# (Opened Chrome DevTools, clicked on Network tab, clicked on Runbook 2)
# what I saw:
#   Request URL: http://localhost:3001/api/runbooks/2
#   Method: GET
#   Status: 200 OK
#   Size: 343 bytes

# why: Check Nginx logs to see if it received and proxied the request
docker compose logs frontend --tail 20
# what I saw:
#   [REDACTED_IP] - - [13/Apr/2026:12:10:27 +0000] "GET /api/runbooks/2 HTTP/1.1" 200 343 ...
# Translation: Nginx received GET request, returned 200 OK, sent 343 bytes

# why: Check API logs to see if it received the proxied request
docker compose logs api --tail 20
# what I saw:
#   INFO [sqlalchemy.engine.Engine] SELECT runbook_steps.runbook_id, ...
#   INFO [sqlalchemy.engine.Engine] WHERE runbook_steps.runbook_id IN ($1::INTEGER)
#   INFO [sqlalchemy.engine.Engine] [cached since 119.1s ago] (2,)
# Translation: API queried PostgreSQL for runbook_id=2, no HTTP request log (FastAPI doesn't log at INFO level by default)

# ============================================================================
# Key Discovery
# ============================================================================
# The request flow:
#   1. Browser sends: GET http://localhost:3001/api/runbooks/2
#   2. Nginx receives it (because port 3001 is published)
#   3. Nginx sees /api/ prefix, uses proxy_pass http://api:8000
#   4. Docker DNS resolves "api" to the API container's IP
#   5. API container queries PostgreSQL
#   6. API returns JSON (343 bytes)
#   7. Nginx forwards response to browser
#   8. Browser displays the runbook
#
# Why this matters:
#   - The browser (host network) cannot directly reach the API (Docker network)
#   - Nginx bridges the two networks via port mapping (3001:3000) and proxy_pass
#   - Docker DNS only works inside the Docker network — "api" resolves for Nginx, not for the browser
#   - This is the same pattern as Kubernetes Ingress → Service → Pod
