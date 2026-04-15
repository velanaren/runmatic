# Sprint 11 — Health Checks & Restart Policies — Notes

## Phase 1 — The Hook
**Claude's Explanation:** 
Restart policies automate the "restart the service" runbook step from on-call rotations. Container crashes → Docker restarts it in 2 seconds, no page, no manual intervention. The incident self-heals.

SIGTERM (graceful shutdown) vs SIGKILL (forced termination): SIGTERM lets the service finish in-flight requests and close connections cleanly before exiting. SIGKILL cuts everything off mid-response — users see errors. The difference between a messy deploy and a professional one.

**First Test:** 
```bash
docker compose up -d
docker compose kill api
docker compose ps
```

**My Result:** API showed exit code 137 (SIGKILL) and stayed stopped. No automatic restart happened.

## Phase 2 — The Build
**Done Condition:** Kill any service → Docker restarts it automatically within 5 seconds. `docker compose stop api` shows clean shutdown logs.

**My Work:**
Created `infra/act1/sprint-11-restart-policies/docker-compose.yml` with:
- `restart: unless-stopped` on all 5 services (api, worker, postgres, redis, frontend)
- `stop_grace_period: 30s` on postgres and worker (need time to flush writes and finish jobs)
- Health check on API:
  ```yaml
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 10s
  ```

**Key observations:**

**Test 1 — Automatic restart after crash:**
- `docker compose kill api` did NOT trigger restart
- Restart count: 0
- **Critical observation:** `docker compose kill` is manual intervention, so `unless-stopped` respects it and doesn't restart
- This is correct behavior — prevents restart loops during debugging

To test real crash, used:
```bash
docker compose exec api sh -lc 'kill 1'
```
- This killed PID 1 inside the container (simulated crash from within)
- Restart count: 1 ✓
- Container automatically restarted

**Test 2 — Graceful shutdown:**
```bash
docker compose stop api
```
- API exited with code 0 (clean shutdown)
- Logs showed graceful shutdown message from Uvicorn

**Test 3 — Health check validation:**
- API started with `health: starting` status
- After ~10 seconds (the start_period), transitioned to `healthy`
- Full dependency chain working: postgres healthy → redis healthy → api starts → api healthy → worker starts

## Phase 3 — The Challenge
**Claude's Challenge:** 
Container is running but marked `unhealthy`. Does the restart policy trigger? Why or why not? What should happen in production?

**My Investigation:**
Two distinct failure modes:
1. **Container crash** (process exits) → exit code ≠ 0 → restart policy triggers → Docker can fix this automatically
2. **Container unhealthy** (process still running, health check fails) → restart policy does NOT trigger → Docker can't fix this automatically

**My Answer:**
Container unhealthy should NOT automatically restart because:
- Restart wouldn't fix the underlying issue
- Would create restart loop: unhealthy → restart → still unhealthy → restart again
- Requires human intervention to diagnose root cause:
  1. Check logs (`docker logs`)
  2. Check if it can reach dependencies (network connectivity)
  3. Inspect health check output (`docker inspect`)

Health check is a diagnostic signal ("something is wrong, come look"), not a restart trigger.

**Claude's Feedback:**
Correct reasoning. In Compose, unhealthy containers stay running because you have one instance — restarting means downtime. In Kubernetes (Act 2), liveness probes DO restart unhealthy pods because K8s has multiple replicas — safe to restart one while others serve traffic. Same health check concept, different remediation strategy based on architecture.

## Phase 4 — Explanation
**Claude's Question:** What is a restart policy and why does `unless-stopped` exist instead of just using `always`?

**My Answer:**
Restart policies automate recovery when containers crash — saves time and avoids manual intervention. If crash is recoverable, it restarts; if health check fails, requires manual diagnosis.

`always` is problematic for maintenance: if you manually stop a container for maintenance, `always` will fight you by restarting it. Can't perform maintenance.

`unless-stopped` is the production choice: tells Docker "if I stop a container manually, don't restart it; if it crashes on its own, restart it."

**Claude's Feedback:**
Core distinction is correct. One clarity issue: opening sentence "if a container crashes docker does not restart it" contradicted the rest — meant "by default without a policy" but didn't say it explicitly.

Score: 8/10 concept, 10/10 execution, +1 speed = 19/20

## Bonus Challenge (9/10)
**Challenge:**
Worker container starts, connects to Redis, registers jobs, but jobs don't execute. `ps aux` shows:
```
PID 1: /bin/sh -c python -m worker.main
PID 7: python -m worker.main
```

**My Investigation:**
Two processes running — PID 1 is a shell wrapper, PID 7 is the actual worker. This is shell form CMD creating a shell as PID 1.

If container is stopped, SIGTERM goes to PID 1 (shell), which doesn't forward it to PID 7 (worker) — not a graceful stop. Leaves broken transactions or unprocessed jobs.

**Claude's Hint:**
Signal handling issue affects more than shutdown. When scheduler needs to send signals to the worker (for job execution, interrupts), signals go to PID 1 (shell), which doesn't forward them to PID 7 (Python). Worker initialized but can't receive signals needed to execute scheduled jobs.

**My Fix:**
Changed docker-compose.yml worker command from shell form:
```yaml
command: python -m worker.main
```

To exec form (JSON array syntax):
```yaml
command: ["python", "-m", "worker.main"]
```

**Result:**
`ps aux` now shows:
```
PID 1: python -m worker.main
```

Only one process. PID 1 is the Python worker directly. SIGTERM goes straight to Python for graceful shutdown. Jobs execute correctly because signals reach the right process.

**Bonus Score:** 4/5 diagnosis (needed one hint, correct reasoning), 5/5 fix (complete and correct) = 9/10

## Key Takeaways
1. **Restart policies encode operational intent:** `unless-stopped` = "fix crashes automatically, but respect manual stops for maintenance"
2. **Health checks are observability, not remediation:** Unhealthy = alert human, don't create restart loop
3. **Signal handling is architecture:** Exec form CMD makes your process PID 1, enabling proper SIGTERM/SIGINT handling
4. **Compose vs K8s remediation differs:** Compose doesn't restart unhealthy (one instance = downtime risk), K8s does (replicas = safe to restart one)
5. **Shell form CMD is a production footgun:** Creates shell wrapper as PID 1, breaks signal forwarding, affects both shutdown AND runtime behavior (job scheduling, interrupts)
6. **stop_grace_period matters for stateful services:** Postgres needs time to flush writes, workers need time to finish jobs — default 10s is often too short
7. **Restart count is a diagnostic signal:** `docker inspect --format '{{.RestartCount}}'` shows crash frequency in production
