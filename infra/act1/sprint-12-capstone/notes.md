# Sprint 12 — Act 1 Capstone — Notes

## Capstone Structure

This sprint had no new content. It was a proof of mastery session across three dimensions:
1. **Operational Proof** — does the system work end-to-end?
2. **Architecture Explanation** — can you teach it to a stranger?
3. **Documentation Quality** — is the audit trail complete?

---

## Part 1 — Operational Proof

### 1. All 5 Services Started Healthy

**Command:**
```bash
docker compose ps
```

**Result:**
```
NAME        IMAGE                                 COMMAND                  SERVICE    CREATED          STATUS                    PORTS
api1        runmatic-api-v2                       "uvicorn app.main:ap…"   api        17 minutes ago   Up 16 minutes (healthy)   0.0.0.0:8000->8000/tcp
frontend1   sprint-11-restart-policies-frontend   "/docker-entrypoint.…"   frontend   2 minutes ago    Up About a minute         0.0.0.0:3001->3000/tcp
postgres1   postgres:15-alpine                    "docker-entrypoint.s…"   postgres   17 minutes ago   Up 16 minutes (healthy)   5432/tcp
redis1      redis:7-alpine                        "docker-entrypoint.s…"   redis      17 minutes ago   Up 16 minutes (healthy)   6379/tcp
worker1     runmatic-worker-v1                    "python -m worker.ma…"   worker     17 minutes ago   Up 16 minutes
```

All services up and healthy. Health checks passing.

---

### 2. Created Runbook via UI

**Action:** Clicked "+ New Runbook" in browser (http://localhost:3001)

**Runbook created:**
- Title: "API Health check failure"
- Service: runmatic-api
- Content: "check status investigate Take action"
- Date: 2026-04-18

**Database verification:**
```bash
docker exec postgres1 psql -U runmatic -d runmatic -c "SELECT id, title, status, created_at FROM runbooks"
```

**Result:**
```
 id |                title                | status  |         created_at
----+-------------------------------------+---------+----------------------------
  1 | API Health Check Failure            | fresh   | 2026-03-19 14:28:01.977749
  2 | Worker Job Queue Backup             | fresh   | 2026-03-04 14:28:01.977749
  3 | Database Connection Pool Exhaustion | warning | 2026-02-17 14:28:01.977749
  4 | Container Restart Loop              | stale   | 2026-01-28 14:28:01.977749
  5 | API Health check failure            | fresh   | 2026-04-18 14:38:31.721452  ← NEW
```

Runbook ID 5 created successfully.

---

### 3. Persistence Verified

**Commands:**
```bash
docker compose down
docker compose up -d
docker exec postgres1 psql -U runmatic -d runmatic -c "SELECT id, title FROM runbooks"
```

**Result:** Runbook ID 5 still present after full restart.

**Volume inspection:**
```bash
docker volume inspect sprint-11-restart-policies_postgres-data
```

**Result:**
```json
{
    "CreatedAt": "2026-04-15T11:57:24Z",
    "Driver": "local",
    "Name": "sprint-11-restart-policies_postgres-data",
    "Mountpoint": "/var/lib/docker/volumes/sprint-11-restart-policies_postgres-data/_data"
}
```

Volume created on April 15, still exists on April 18. Data persists across container lifecycle.

**Key insight from Vela:** "volume and data will go away only when we give docker compose down -v else volume will persist"

---

### 4. Restart Policy Tested

**Initial attempt (manual stop — should NOT restart):**
```bash
docker compose kill api
```

**Vela's observation:** "docker compose kill api will not allow restart because docker will treat this as stopped by user, so it will not restart as we have provided condition 'unless-stopped'"

This is **exactly correct**. The `unless-stopped` policy means:
- Container crashes → automatic restart
- Manual stop → no restart (respects operator intent)

**Correct test (simulated crash):**
```bash
docker compose exec api sh -lc 'kill 1'
```

This kills PID 1 inside the container, simulating a real crash (not a manual stop).

**Result:**
```bash
docker compose ps
```

```
NAME   IMAGE              STATUS                           PORTS
api1   runmatic-api-v2   Up 1 second (health: starting)   0.0.0.0:8000->8000/tcp
```

API container restarted. Health check shows "starting" → transitions to "healthy" after 10 seconds.

**Follow-up check:**
```
api1   runmatic-api-v2   Up 5 seconds (healthy)   0.0.0.0:8000->8000/tcp
```

All other services up for 6 minutes. API up for 5 seconds. Restart confirmed.

---

## Part 2 — Architecture Explanation

### Q1 — Network Topology

**Vela's Answer:**
> "Frontend and API. Worker with postgres, redis, and api. API with postgres and redis.
>
> In case if we run them as independent containers they will get attached to default bridge. They may be able to connect through IP address but not through hostname as it cannot resolve DNS. The next step is to create the network and then tag these services to the network — in this case they can resolve with hostname and communicate with each other. Even better option is to use docker compose, it automatically tags all services in the compose file to a network."

**What this demonstrates:**
- Correct communication graph
- Understanding of bridge network limitations (no DNS)
- Understanding of custom networks (DNS enabled)
- Understanding of docker compose networking (automatic network creation)

**What's missing:** The specific network name is `sprint-11-restart-policies_default` (compose project name + `_default`).

---

### Q2 — Volume Strategy

**Vela's Answer:**
> "Containers are meant to be ephemeral, disposable and replaceable. But that is not the case with data. For business operations, data has to be persistent. Container lifecycle should be separated from data lifecycle.
>
> Any data that is critical for business should persist, without this operations will break — this is stored in postgres. Data that is created for the operations (jwt sessions, temporary files, triggers) — these are ephemeral, this is not required to be persistent, this data is enough for the session or the time til container is alive."

**What this demonstrates:**
- Core principle: container lifecycle ≠ data lifecycle
- Business-driven decision making (what must persist for operations to function?)
- Correct classification: postgres (persistent), redis (ephemeral for this use case)

**Perfect answer.** This is the insight that separates junior from senior infrastructure engineers.

---

### Q3 — Dockerfile Layer Ordering

**Vela's Answer:**
> "Dockerfile is a series of instructions we provide to build the image. The order of instructions matter for build speed because the rule is if we change any layer in the docker file, the layer below it will be rebuilt and the layer above it will be not. That is why most stable content should be on top of the file and most unstable/frequently modified content should be on the bottom of the docker file.
>
> E.g:
> ```
> FROM python:3.11-slim
> WORKDIR /app
> COPY requirements.txt .
> COPY alembic.ini .
> RUN pip install --no-cache-dir -r requirements.txt
> COPY migrations ./migrations
> EXPOSE 8000
> COPY app ./app
> CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
> ```
>
> The app code is the frequently changed one in this file. If we keep this at the top anything below it will be rebuilt and the rebuild time will increase."

**What this demonstrates:**
- Correct principle: stable layers on top, changing layers on bottom
- Correct example from actual Dockerfile
- Correct reasoning: app code changes frequently → goes at bottom

**Minor wording issue:** "layer below it will be rebuilt" could be clearer as "layers after it (later in the file) will be invalidated." But the example proves the understanding is correct.

---

### Q4 — Startup Dependency Chain

**Vela's Answer:**
> "This is the order:
> 1. postgres will start
> 2. redis will start
> 3. api - will start only if postgres and redis are up and have passed the defined health check
> 4. frontend - will start only after api is up and passed the defined health check
> 5. worker - will start only if postgres, redis, api are up and all have passed the health check
>
> Health checks are defined for the service, they run based on the parameters defined like interval, retries, timeout. Health check ensures the dependent services are not just up, but they are up and doing the desired function."

**What this demonstrates:**
- Complete dependency graph
- Understanding of health check vs simple `depends_on`
- Purpose of health checks: readiness, not just liveness

**Perfect answer.** The distinction between "up" and "doing the desired function" is exactly right. `depends_on: condition: service_healthy` waits for the health check to pass, not just for the process to start.

---

## Part 3 — Documentation Quality

**Audit command:**
```bash
find infra/act1 -type f \( -name "SCORE.md" -o -name "notes.md" -o -name "commands.sh" \) | sort
```

**Result:**
All 11 sprints (01-11) have complete documentation:
- SCORE.md (scoring + carry-forward)
- notes.md (conversation + observations)
- commands.sh (executable command history)

**Spot check:**
```bash
wc -l infra/act1/sprint-05-volumes/SCORE.md infra/act1/sprint-10-multistage/notes.md infra/act1/sprint-11-restart-policies/commands.sh
```

**Result:**
```
      43 infra/act1/sprint-05-volumes/SCORE.md
     147 infra/act1/sprint-10-multistage/notes.md
     118 infra/act1/sprint-11-restart-policies/commands.sh
     308 total
```

Files are substantial, not placeholders.

**Infrastructure artifacts present:**
- Sprint 03: Dockerfile.api, Dockerfile.worker
- Sprint 07-11: docker-compose.yml evolution (v1 → redis added → frontend → multi-stage → health checks)
- Sprint 09: Dockerfile.frontend
- Sprint 10-11: Multi-stage Dockerfiles

Complete audit trail from first `docker run` to production-ready compose stack.

---

## Key Takeaways

1. **Operational knowledge isn't theoretical.** You proved you can run the system, test it under failure conditions, and verify expected behavior. The distinction between crash (kill 1) and manual stop (docker compose kill) is what matters in a 2am incident.

2. **Architecture understanding enables teaching.** You explained the full system to a hypothetical new SRE without looking at files. Network topology, volume strategy, layer caching, startup dependencies — all from memory.

3. **Documentation is proof of work.** All 11 sprints documented. Every command logged. Every score justified. In an interview, you can open any sprint folder and walk through exactly what you built and why.

4. **Act 1 complete.** Docker is no longer a black box. You can containerize applications, orchestrate multi-service stacks, optimize builds, implement self-healing with restart policies and health checks, and debug production infrastructure.

**Next: Kubernetes.** Same app, radically different substrate. You're not running containers — you're declaring desired state and letting the control plane reconcile reality to match.
