# Sprint 08 — Docker Compose v2
**Score:** 20/20  (Concept: 9/10 | Execution: 10/10 | Speed: +1)
**Date:** 2026-04-11
**Duration:** Approx 30 min

---

## What You Got Right

**The critical distinction: service_healthy vs service_started.** You explained it perfectly: `condition: service_healthy` waits for the health check to pass (container doing its intended job), while `condition: service_started` just waits for the process to exist (container running, maybe not ready). This is the difference between a reliable system and a flaky one.

**Independent discovery: worker depends on API healthy, not just postgres.** You saw the error `relation runbook does not exist`, traced it to migrations not having run yet, realized the API runs migrations, and added API as a worker dependency. This is systems thinking — understanding the complete dependency graph, not just the obvious connections. In an interview, this demonstrates architectural understanding beyond the immediate task.

**Production-grade health check debugging.** When changing the username to `wronguser` didn't fail the health check, you didn't just move on. You tested both commands independently with `docker exec`, discovered that `pg_isready` only checks if postgres accepts connections (not authentication), and wrote the correct failing health check using `psql`. This is the kind of investigative work that prevents production incidents.

## What You Missed

**Brevity in explanation.** Asked for 3 sentences, you gave a comprehensive breakdown. The content was excellent and showed deep understanding, but in an incident channel or standup, you'd need to condense. Practice: "Health checks test if a service is doing its job, not just running. `service_healthy` waits for the check to pass; `service_started` just waits for the process. This prevents the API from starting before postgres is ready to accept queries."

**Health check parameter explanation.** You configured `interval`, `timeout`, `retries`, and `start_period` correctly, but didn't mention them in your Phase 4 explanation. Those parameters control the detection speed vs noise tradeoff: short interval catches failures fast but creates load; long retries tolerate transient issues but delay failure detection.

## Carry Forward

Health checks in Compose (`test`, `interval`, `timeout`, `retries`, `start_period`) are the foundation for Kubernetes **liveness and readiness probes** in Sprint 14. The concepts are identical — liveness = "restart if this fails," readiness = "don't send traffic if this fails." You're already thinking in those terms. When you see `livenessProbe` in a K8s manifest, it's the same `pg_isready` command you wrote today, just different YAML.

## What This Teaches About Production Systems

`pg_isready` vs `psql` is the health check equivalent of "is the server responding to ping?" vs "can users actually log in?" A postgres container that accepts connections but rejects authentication is **unhealthy**, not healthy. This happens in production: corrupted pg_hba.conf, wrong password in the secret, auth plugin misconfigured. `pg_isready` says healthy. Users can't log in. The health check you wrote with `psql` would catch it.

Your worker dependency discovery mirrors a real production pattern: microservices that depend on **schema migrations**, not just database availability. The database is up. The tables don't exist yet. The service crashes. This is why tools like Liquibase and Flyway have "wait for schema version X" checks. You solved it at the orchestration layer by making the worker depend on the API (which runs migrations). In Kubernetes, this becomes an **init container** pattern. You'll see it in Sprint 14.

## Bonus Challenge
Unlocked: Yes
Attempted: Yes
Result: 7/10

### Bonus — Redis Bind Misconfiguration

**Challenge:** All 4 services start. `docker compose ps` shows redis healthy. But API health returns `{"status":"degraded","cache":"disconnected"}`. Redis is running, health check passes. Why can't the API reach it?

**Diagnosis: 5/5** — Root cause identified correctly: Redis configured with `command: redis-server --bind 127.0.0.1`, making it listen only on localhost inside its own container. Health check passes because `redis-cli ping` runs INSIDE the redis container, where localhost is available. API can't connect because it's in a different container trying to reach `redis:6379` (the network IP), but Redis isn't listening on that interface — only on 127.0.0.1.

**Fix: 2/5** — You identified what was wrong but didn't complete the fix. You simulated the broken state and showed the error (`Error 111 connecting to redis:6379`), but you didn't show the working state: remove `--bind 127.0.0.1`, restart, and verify `curl localhost:8000/health` returns `"cache":"connected"`. Diagnosis without verified fix is incomplete.

**What was missing:** The final step — prove the fix works. In production incident response, "I know what's wrong" doesn't resolve the ticket. "I fixed it and here's the health check confirming services are green" does.

**Total: 7/10**
