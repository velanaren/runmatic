# Sprint 11 — Health Checks & Restart Policies
**Score:** 19/20  (Concept: 8/10 | Execution: 10/10 | Speed: +1)
**Date:** 2026-04-15
**Duration:** Approx 28 min

---

## What You Got Right
- **Restart policy implementation:** All 5 services configured with `unless-stopped`, stop_grace_period added to postgres and worker (30s), API health check properly implemented with correct intervals and start_period
- **Critical observation:** Identified that `docker compose kill` doesn't trigger restart because it's manual intervention — Docker respects operator intent with `unless-stopped`, preventing restart loops during debugging
- **Health check vs crash distinction:** Correctly reasoned that unhealthy containers should NOT auto-restart (would create restart loop), requiring human diagnosis of root cause — logs, dependency checks, inspect health check output
- **Troubleshooting:** Debugged missing kill binary issue with `sh -lc 'kill 1'` workaround without help

## What You Missed
- **Explanation clarity:** Opening sentence "If a container crashes docker does not restart it" contradicted the rest of your explanation. You meant "by default, without a policy" but didn't state it explicitly. The rest was solid — `unless-stopped` vs `always` for maintenance, manual stop vs crash distinction.

## Carry Forward
Graceful shutdown depends on exec form CMD (Sprint 03 lesson verified here). Shell form `CMD python -m worker.main` wraps your process in /bin/sh (PID 1), which doesn't forward SIGTERM to the actual Python process (PID 7). Exec form `CMD ["python", "-m", "worker.main"]` makes Python PID 1, so it receives SIGTERM directly and can shut down gracefully. This becomes critical in Sprint 12 when you walk through the full dependency chain — signal handling is part of that architecture.

## What This Teaches About Production Systems
Restart policies aren't just automation — they encode operational intent. `unless-stopped` says "if this crashes, fix it automatically, but if I stop it on purpose, respect that." This prevents the nightmare scenario: you stop a container to investigate, the policy fights you by restarting it, you kill it again, it restarts again. With `unless-stopped`, Docker knows the difference between "failed" and "stopped for maintenance."

Health checks are observability signals, not remediation triggers. An unhealthy container in Compose stays running because you have one instance — restarting it means downtime. Better to alert a human than create a restart loop. In Kubernetes (Act 2), you'll add liveness probes that DO restart unhealthy pods — because K8s runs multiple replicas, so restarting one broken pod while others serve traffic is safe. Same health check concept, different remediation strategy based on architecture.

Every production system needs this: automated recovery for known-good failure modes (crash = restart), human escalation for ambiguous ones (unhealthy = investigate).

## Bonus Challenge
**Unlocked:** Yes (19/20)
**Attempted:** Yes
**Result:** 9/10

### Challenge
Worker container starts successfully, connects to Redis, registers scheduled jobs, but jobs don't execute. `ps aux` shows:
```
PID 1: /bin/sh -c python -m worker.main
PID 7: python -m worker.main
```

### Diagnosis (4/5)
Identified shell form CMD creating two processes — PID 1 is the shell wrapper, PID 7 is the actual worker. Correctly connected this to signal handling: when the scheduler or system sends signals to the container, they go to PID 1 (shell), which doesn't forward them to PID 7 (Python worker). This breaks both job execution and graceful shutdown. Needed one hint to focus on the PID layout. Reasoning was solid once the two-process structure was clear.

### Fix (5/5)
Changed worker command from shell form `python -m worker.main` to exec form `["python", "-m", "worker.main"]` in docker-compose.yml. Verified PID 1 is now the Python process directly. Explained why this enables graceful shutdown: SIGTERM now goes straight to Python, which can finish current job, close connections, and exit cleanly. Complete and correct.

### Lesson
Shell form CMD is a production footgun. It looks identical to exec form in simple cases but breaks signal handling — the foundation of graceful shutdown, job scheduling signals, and container lifecycle management. Always use exec form (JSON array syntax) for services. This Sprint 03 lesson has now been proven twice: once in theory (Dockerfile), once in production consequence (worker broken).
